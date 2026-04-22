import AppKit
import CoreGraphics
import Foundation
import OSLog
import BrowserRouterCore

private let appDelegateLogger = Logger(subsystem: "local.browser-router", category: "app-delegate")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var configuration = RouterConfiguration.load()
    private let launcher = BrowserLauncher()
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var chooserWindowController: BrowserChooserWindowController?
    private var defaultBrowserManager: DefaultBrowserManager?
    private var lastConfigModificationDate: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaultBrowserManager = try? DefaultBrowserManager()
        configuration = cleanupGhostBrowsersIfNeeded()
        rememberConfigModificationDate()
        applyPresentationSettings()
        if needsOnboarding(forceReload: true) {
            openOnboarding()
        } else {
            showSettingsIfPresentationHidden()
        }
    }

    func applicationShouldHandleReopen(_ application: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else {
            return true
        }

        if needsOnboarding(forceReload: true) {
            openOnboarding()
        } else {
            showSettingsIfPresentationHidden()
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            handle(url)
        }
    }

    private func installStatusItem() {
        guard statusItem == nil else {
            statusItem?.menu = buildStatusMenu()
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Router"
        item.menu = buildStatusMenu()
        statusItem = item
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(actionMenuItem(
            title: "Settings...",
            systemImageName: "gearshape",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        menu.addItem(.separator())

        let manager = currentDefaultBrowserManager()
        menu.addItem(statusHeaderItem("Routing"))
        for item in statusItems(for: manager) {
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(actionMenuItem(
            title: "Quit",
            systemImageName: "power",
            action: #selector(quit),
            keyEquivalent: "q"
        ))
    }

    private func removeStatusItem() {
        guard let statusItem else {
            return
        }

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func applyPresentationSettings() {
        let desiredPolicy: NSApplication.ActivationPolicy = configuration.showsDockIcon ? .regular : .accessory
        if NSApp.activationPolicy() != desiredPolicy {
            NSApp.setActivationPolicy(desiredPolicy)
        }

        if configuration.showsStatusItem {
            installStatusItem()
        } else {
            removeStatusItem()
        }
    }

    private func showSettingsIfPresentationHidden() {
        guard !configuration.showsDockIcon, !configuration.showsStatusItem else {
            return
        }

        openSettings()
    }

    private func needsOnboarding(forceReload: Bool = false) -> Bool {
        if !configuration.hasCompletedOnboarding {
            return true
        }

        guard let manager = currentDefaultBrowserManager(forceReload: forceReload) else {
            return false
        }

        return !manager.isRoutingToSelf()
    }

    private func handle(_ url: URL) {
        refreshConfigurationIfNeeded()

        if shouldShowChooser() {
            showChooser(for: url)
            return
        }

        if let option = routedOption(for: url) {
            launcher.open(url, with: option)
            return
        }

        let configuredDefault = configuration.browserOptions.first { $0.id == configuration.defaultOptionID }
        let option = configuredDefault.flatMap { launcher.isInstalled($0) ? $0 : nil }
            ?? availableBrowserOptions().first

        if let option {
            launcher.open(url, with: option)
        } else {
            showChooser(for: url)
        }
    }

    private func shouldShowChooser() -> Bool {
        guard let modifier = ChooserModifier(rawValue: configuration.chooserModifier) else {
            return ChooserModifier.commandShift.matches(CGEventSource.flagsState(.hidSystemState))
        }

        let flags = CGEventSource.flagsState(.hidSystemState)
        return modifier.matches(flags)
    }

    private func routedOption(for url: URL) -> BrowserOption? {
        for rule in configuration.routingRules where RuleMatcher.matches(rule, url: url) {
            guard let option = configuration.browserOptions.first(where: { $0.id == rule.browserOptionID }) else {
                continue
            }

            if launcher.isInstalled(option) {
                return option
            }
        }

        return nil
    }

    private func showChooser(for url: URL) {
        NSApp.activate(ignoringOtherApps: true)

        let options = Array(availableBrowserOptions().prefix(12))
        guard !options.isEmpty else {
            showMessage(
                title: "No Available Browsers",
                message: "BrowserRouter could not find any installed browsers from the current configuration. Open Settings and refresh the detected browsers."
            )
            return
        }

        chooserWindowController?.close()
        let controller = BrowserChooserWindowController(
            url: url,
            options: options,
            defaultOptionID: configuration.defaultOptionID,
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onSelect: { [weak self] option in
                appDelegateLogger.info("BrowserRouter chooser selected option \(option.id, privacy: .public) for \(url.absoluteString, privacy: .public)")
                self?.launcher.open(url, with: option)
            },
            onClose: { [weak self] in
                self?.chooserWindowController = nil
            }
        )
        chooserWindowController = controller
        controller.showNearMouse()
    }

    private func availableBrowserOptions() -> [BrowserOption] {
        BrowserAvailability.installedOptions(from: configuration.browserOptions)
    }

    private func performSetAsDefaultBrowser(
        showAlert: Bool,
        completion: ((Bool, RouterConfiguration) -> Void)? = nil
    ) {
        Task { @MainActor in
            do {
                guard let manager = currentDefaultBrowserManager(forceReload: true) else {
                    if showAlert {
                        showMessage(
                            title: "Could Not Set BrowserRouter As Default",
                            message: "BrowserRouter could not initialize its default-handler manager."
                        )
                    }
                    completion?(false, configuration)
                    return
                }

                guard manager.isInstalledInApplications() else {
                    if showAlert {
                        showMessage(
                            title: "Install BrowserRouter First",
                            message: "Move BrowserRouter.app into /Applications before setting it as the default browser. The new scripts/install.sh command does this for you."
                        )
                    }
                    completion?(false, configuration)
                    return
                }

                let previousDefaultHandler = manager.currentExternalDefaultHandler()
                try await manager.setAsDefaultBrowser()
                if let previousDefaultHandler {
                    adoptPreviousDefaultBrowser(previousDefaultHandler)
                }
                appDelegateLogger.info("BrowserRouter default handler set successfully:\n\(manager.statusSummary(), privacy: .public)")
                if showAlert {
                    showMessage(
                        title: "BrowserRouter Is Now The Default",
                        message: manager.statusSummary()
                    )
                }
                settingsWindowController?.reload(with: configuration)
                onboardingWindowController?.reload(with: configuration, isRoutingToSelf: manager.isRoutingToSelf())
                completion?(true, configuration)
            } catch {
                appDelegateLogger.error("BrowserRouter failed to become the default browser: \(String(describing: error), privacy: .public)")
                if showAlert {
                    showMessage(
                        title: "Could Not Set BrowserRouter As Default",
                        message: "\(error.localizedDescription)\n\nCurrent handlers:\n\((currentDefaultBrowserManager()?.statusSummary()) ?? "Unavailable")"
                    )
                }
                completion?(false, configuration)
            }
        }
    }

    private func openOnboarding() {
        configuration = cleanupGhostBrowsersIfNeeded()
        rememberConfigModificationDate()
        applyPresentationSettings()

        let manager = currentDefaultBrowserManager(forceReload: true)
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController(
                configuration: configuration,
                isRoutingToSelf: manager?.isRoutingToSelf() ?? false,
                onRequestSetAsDefaultBrowser: { [weak self] completion in
                    self?.performSetAsDefaultBrowser(showAlert: false, completion: completion)
                },
                onComplete: { [weak self] newConfiguration in
                    self?.configuration = newConfiguration
                    self?.rememberConfigModificationDate()
                    self?.applyPresentationSettings()
                    self?.settingsWindowController?.reload(with: newConfiguration)
                    self?.onboardingWindowController = nil
                }
            )
        } else {
            onboardingWindowController?.reload(with: configuration, isRoutingToSelf: manager?.isRoutingToSelf() ?? false)
        }

        onboardingWindowController?.showWindow(nil)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        if needsOnboarding(forceReload: true) {
            openOnboarding()
            return
        }

        configuration = cleanupGhostBrowsersIfNeeded()
        rememberConfigModificationDate()
        applyPresentationSettings()

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                configuration: configuration,
                onSave: { [weak self] newConfiguration in
                    self?.configuration = newConfiguration
                    self?.rememberConfigModificationDate()
                    self?.applyPresentationSettings()
                }
            )
        } else {
            settingsWindowController?.reload(with: configuration)
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func currentDefaultBrowserManager(forceReload: Bool = false) -> DefaultBrowserManager? {
        if forceReload || defaultBrowserManager == nil {
            defaultBrowserManager = try? DefaultBrowserManager()
        }

        return defaultBrowserManager
    }

    private func adoptPreviousDefaultBrowser(_ handler: DefaultBrowserHandler) {
        var updatedConfiguration = BrowserInventory.refreshConfiguration(configuration).configuration
        updatedConfiguration.adoptDefaultBrowser(
            bundleIdentifier: handler.bundleIdentifier,
            displayName: handler.displayName,
            appName: handler.appName
        )

        do {
            try updatedConfiguration.save()
            configuration = updatedConfiguration
            rememberConfigModificationDate()
            settingsWindowController?.reload(with: configuration)
        } catch {
            appDelegateLogger.error("BrowserRouter failed to persist previous default browser \(handler.bundleIdentifier, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    private func actionMenuItem(title: String, systemImageName: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.image = menuIcon(named: systemImageName)
        return item
    }

    private func statusHeaderItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.image = menuIcon(named: "arrow.triangle.branch")
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        return item
    }

    private func statusLineItem(title: String, emphasized: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: emphasized ? NSColor.labelColor : NSColor.secondaryLabelColor
            ]
        )
        return item
    }

    private func selectedBrowserProfileName() -> String {
        configuration.browserOptions.first(where: { $0.id == configuration.defaultOptionID })?.name
            ?? "Unknown browser/profile"
    }

    private func statusItems(for manager: DefaultBrowserManager?) -> [NSMenuItem] {
        guard let manager else {
            return [
                statusLineItem(title: "Status unavailable", emphasized: true),
                statusLineItem(title: "Open Settings to check your browser profile")
            ]
        }

        if manager.isRoutingToSelf() {
            var items: [NSMenuItem] = [
                statusLineItem(title: "Opening with \(selectedBrowserProfileName())", emphasized: true)
            ]

            let modifier = ChooserModifier(rawValue: configuration.chooserModifier) ?? .commandShift
            if modifier == .always {
                items.append(statusLineItem(title: "Chooser always on"))
            } else {
                items.append(statusLineItem(title: "Hold \(modifier.title) for chooser"))
            }

            return items
        }

        return [
            statusLineItem(title: "BrowserRouter is not the default browser", emphasized: true)
        ]
    }

    private func menuIcon(named systemImageName: String) -> NSImage? {
        NSImage(systemSymbolName: systemImageName, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .regular))
    }

    private func showMessage(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func cleanupGhostBrowsersIfNeeded() -> RouterConfiguration {
        let loaded = RouterConfiguration.load()
        let result = BrowserInventory.refreshConfiguration(loaded)
        guard result.changed || result.configuration.defaultOptionID != loaded.defaultOptionID else {
            return loaded
        }

        do {
            try result.configuration.save()
        } catch {
            appDelegateLogger.error("BrowserRouter failed to persist browser cleanup: \(String(describing: error), privacy: .public)")
        }

        return result.configuration
    }

    private func refreshConfigurationIfNeeded() {
        guard let modificationDate = configModificationDate() else {
            guard lastConfigModificationDate != nil else {
                return
            }

            configuration = RouterConfiguration.load()
            rememberConfigModificationDate()
            applyPresentationSettings()
            appDelegateLogger.info("BrowserRouter recreated config after it was removed")
            return
        }

        guard modificationDate != lastConfigModificationDate else {
            return
        }

        configuration = RouterConfiguration.load()
        rememberConfigModificationDate()
        applyPresentationSettings()
        appDelegateLogger.info("BrowserRouter reloaded config after external modification")
    }

    private func rememberConfigModificationDate() {
        lastConfigModificationDate = configModificationDate()
    }

    private func configModificationDate() -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: RouterConfiguration.configURL.path)
        return attributes?[.modificationDate] as? Date
    }
}
