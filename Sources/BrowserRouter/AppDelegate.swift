import AppKit
import CoreGraphics
import Foundation
import OSLog
import BrowserRouterCore

private let appDelegateLogger = Logger(subsystem: "local.browser-router", category: "app-delegate")

/// Returns the parent PID for a given PID via sysctl, or 0 on failure.
private func getppid_for(_ pid: pid_t) -> pid_t {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.size
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return 0 }
    return info.kp_eproc.e_ppid
}

/// Returns the process name for a given PID via sysctl, or nil on failure.
private func getProcessName(_ pid: pid_t) -> String? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.size
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
    return withUnsafePointer(to: info.kp_proc.p_comm) { ptr in
        ptr.withMemoryRebound(to: CChar.self, capacity: 17) {
            String(cString: $0)
        }
    }
}

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
    let keyMonitor = KeyStateMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        keyMonitor.start()
        installMainMenu()
        defaultBrowserManager = try? DefaultBrowserManager()
        configuration = cleanupGhostBrowsersIfNeeded()
        
        if configuration.hasCompletedOnboarding, configuration.autoRestoreDefaultBrowserOnQuit {
            if let manager = defaultBrowserManager, !manager.isRoutingToSelf() {
                Task { @MainActor in
                    try? await manager.setAsDefaultBrowser()
                }
            }
        }
        
        rememberConfigModificationDate()
        applyPresentationSettings()
        if needsOnboarding(forceReload: true) {
            openOnboarding()
        } else {
            showSettingsIfPresentationHidden()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if configuration.autoRestoreDefaultBrowserOnQuit,
           let previous = restoreDefaultBrowserCandidate(),
           let manager = currentDefaultBrowserManager(),
           manager.isRoutingToSelf() {
            let alert = NSAlert()
            alert.messageText = "Quit BrowserRouter?"
            alert.informativeText = "BrowserRouter is currently your macOS default browser. If you quit it, links will no longer route through BrowserRouter. Restore your previous default browser, \(previous.displayName), before quitting?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Restore \(previous.displayName) and Quit")
            alert.addButton(withTitle: "Keep BrowserRouter Running")
            alert.addButton(withTitle: "Quit Without Restoring")
            NSApp.activate(ignoringOtherApps: true)

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                break
            case .alertSecondButtonReturn:
                return .terminateCancel
            default:
                return .terminateNow
            }

            Task { @MainActor in
                do {
                    try await manager.restoreDefaultBrowser(to: previous)
                    NSApp.reply(toApplicationShouldTerminate: true)
                } catch {
                    showMessage(
                        title: "Could Not Restore Default Browser",
                        message: "\(error.localizedDescription)\n\nBrowserRouter will keep running so your links continue to work."
                    )
                    NSApp.reply(toApplicationShouldTerminate: false)
                }
            }
            return .terminateLater
        }
        return .terminateNow
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "BrowserRouter")
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit BrowserRouter",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        appMenu.addItem(quitItem)
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    func applicationShouldHandleReopen(_ application: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if needsOnboarding(forceReload: true) {
            openOnboarding()
        } else {
            openSettings()
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let sourceApp = detectSourceAppBundleID()
        if let sourceApp {
            appDelegateLogger.info("BrowserRouter detected source app: \(sourceApp, privacy: .public)")
        }

        for url in urls where ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            handle(url, sourceApp: sourceApp)
        }
    }

    private func installStatusItem() {
        guard statusItem == nil else {
            statusItem?.menu = buildStatusMenu()
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusButton(item.button)
        item.menu = buildStatusMenu()
        statusItem = item
    }

    private func configureStatusButton(_ button: NSStatusBarButton?) {
        guard let button else {
            return
        }

        button.title = ""
        button.image = makeStatusItemIcon()
        button.imagePosition = .imageOnly
        button.toolTip = "BrowserRouter"
        button.setAccessibilityLabel("BrowserRouter")
    }

    private func makeStatusItemIcon() -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.black.setStroke()
        NSColor.black.setFill()

        let transform = NSAffineTransform()
        transform.translateX(by: 0, yBy: size.height)
        transform.scaleX(by: 1, yBy: -1)
        transform.concat()

        func strokePath(_ path: NSBezierPath, width: CGFloat = 2.1) {
            path.lineWidth = width
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }

        let trunk = NSBezierPath()
        trunk.move(to: NSPoint(x: 3, y: 11))
        trunk.line(to: NSPoint(x: 8.9, y: 11))
        strokePath(trunk)

        let upperRoute = NSBezierPath()
        upperRoute.move(to: NSPoint(x: 8.9, y: 11))
        upperRoute.curve(
            to: NSPoint(x: 13.8, y: 7),
            controlPoint1: NSPoint(x: 11, y: 10.9),
            controlPoint2: NSPoint(x: 12.3, y: 9.7)
        )
        strokePath(upperRoute)

        let lowerRoute = NSBezierPath()
        lowerRoute.move(to: NSPoint(x: 8.9, y: 11))
        lowerRoute.curve(
            to: NSPoint(x: 13.7, y: 15),
            controlPoint1: NSPoint(x: 11, y: 11.1),
            controlPoint2: NSPoint(x: 12.2, y: 12.3)
        )
        strokePath(lowerRoute)

        NSBezierPath(ovalIn: NSRect(x: 13.7, y: 2.6, width: 5.2, height: 5.2)).fill()
        NSBezierPath(roundedRect: NSRect(x: 13.7, y: 14.2, width: 5.2, height: 5.2), xRadius: 1.1, yRadius: 1.1).fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
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

        if configuration.autoRestoreDefaultBrowserOnQuit {
            return false
        }

        guard let manager = currentDefaultBrowserManager(forceReload: forceReload) else {
            return false
        }

        return !manager.isRoutingToSelf()
    }

    private func handle(_ url: URL, sourceApp: String? = nil) {
        refreshConfigurationIfNeeded()

        if shouldShowChooser() {
            showChooser(for: url)
            return
        }

        if let option = routedOption(for: url, sourceApp: sourceApp) {
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

    func shouldShowChooser() -> Bool {
        guard let modifier = ChooserModifier(rawValue: configuration.chooserModifier) else {
            return keyMonitor.modifiersMatch([.maskCommand, .maskShift])
        }

        switch modifier {
        case .always:
            return true

        case .custom:
            guard let rawFlags = configuration.customChooserFlags else {
                // No shortcut recorded yet — fall back to commandShift
                return keyMonitor.modifiersMatch([.maskCommand, .maskShift])
            }
            let recorded = CGEventFlags(rawValue: rawFlags)
            let modMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
            let requiredMods = recorded.intersection(modMask)

            // If the shortcut has modifier bits, all must be held
            if !requiredMods.isEmpty && !keyMonitor.modifiersMatch(requiredMods) {
                return false
            }
            // If the shortcut includes a non-modifier key, check it too
            if let kc = configuration.customChooserKeyCode {
                return keyMonitor.isKeyPressed(kc)
            }
            return !requiredMods.isEmpty

        default:
            // Built-in modifier combos — use cached flags
            return modifier.matches(keyMonitor.effectiveFlags)
        }
    }

    private func routedOption(for url: URL, sourceApp: String? = nil) -> BrowserOption? {
        let availableOptions = availableBrowserOptions()
        let availableOptionIDs = Set(availableOptions.map(\.id))
        let resolution = RouteResolver.resolve(
            url: url,
            configuration: configuration,
            availableOptionIDs: availableOptionIDs,
            sourceApp: sourceApp
        )
        let host = url.host?.lowercased() ?? "unknown"

        switch resolution {
        case .matchedRule(let rule, let option):
            appDelegateLogger.info("BrowserRouter matched rule \(rule.id, privacy: .public) for host \(host, privacy: .public), target \(option.id, privacy: .public)")
            return option
        case .unavailableRule(let rule, let option):
            let targetID = option?.id ?? rule.browserOptionID
            appDelegateLogger.info("BrowserRouter matched rule \(rule.id, privacy: .public) for host \(host, privacy: .public), but target \(targetID, privacy: .public) is unavailable")
            return availableDefaultOrFallback(from: availableOptions)
        case .defaultRoute(let option):
            return option
        case .unavailableDefault:
            return availableDefaultOrFallback(from: availableOptions)
        case .fallback(let option):
            return option
        case .chooserOverride, .noOptions:
            return nil
        }
    }

    private func availableDefaultOrFallback(from availableOptions: [BrowserOption]) -> BrowserOption? {
        availableOptions.first
    }

    /// Extracts the bundle ID of the application that sent the current GURL Apple Event.
    private func detectSourceAppBundleID() -> String? {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else {
            appDelegateLogger.debug("Source Detection: [Link Source] No currentAppleEvent found (likely triggered via system internal path or 'open' command)")
            return nil
        }

        let keyAddressAttr = AEKeyword(0x61646472) // 'addr'
        guard let desc = event.attributeDescriptor(forKeyword: keyAddressAttr) else {
            appDelegateLogger.debug("Source Detection: [Link Source] Event exists but 'addr' attribute (keyAddressAttr) is missing")
            return nil
        }
        
        // Check descriptor type. 1886613024 is 'psn '
        guard desc.descriptorType == 1886613024 else {
            let typeStr = String(format: "%c%c%c%c", 
                               (desc.descriptorType >> 24) & 0xFF,
                               (desc.descriptorType >> 16) & 0xFF,
                               (desc.descriptorType >> 8) & 0xFF,
                               desc.descriptorType & 0xFF)
            appDelegateLogger.debug("Source Detection: [Link Source] Found address attribute but type is '\(typeStr)' not 'psn '")
            return nil
        }

        guard desc.data.count == 8 else {
            appDelegateLogger.debug("Source Detection: [Link Source] PSN data length mismatch (expected 8 bytes, got \(desc.data.count))")
            return nil
        }

        var senderPID: pid_t = 0
        desc.data.withUnsafeBytes { buf in
            // PSN is two UInt32s. The PID is often in the low word on modern macOS, 
            // but the reliable way is the little-endian low word mapping for ProcessSerialNumber.
            senderPID = pid_t(buf.load(fromByteOffset: 4, as: UInt32.self).littleEndian)
        }

        guard senderPID > 1 else {
            appDelegateLogger.debug("Source Detection: [Link Source] Resolved PID is invalid (\(senderPID))")
            return nil
        }

        guard let app = NSRunningApplication(processIdentifier: senderPID) else {
            appDelegateLogger.debug("Source Detection: [Link Source] No running application found for PID \(senderPID) (process may have exited)")
            return nil
        }

        // CRITICAL: We only trust .regular (GUI) apps to avoid misattribution to shells, 
        // launchers, or background daemons that just pass through the event.
        guard app.activationPolicy == .regular else {
            appDelegateLogger.debug("Source Detection: [Link Source] Rejected PID \(senderPID) (\(app.bundleIdentifier ?? "unknown")). Policy is \(app.activationPolicy.rawValue == 1 ? ".accessory" : ".prohibited"), not .regular")
            return nil
        }

        guard let bundleID = app.bundleIdentifier else {
            appDelegateLogger.debug("Source Detection: [Link Source] Application found but bundleIdentifier is nil for PID \(senderPID)")
            return nil
        }

        appDelegateLogger.info("Source Detection: [Link Source] RESOLVED -> \(bundleID) (PID: \(senderPID))")
        return bundleID
    }

    private func showChooser(for url: URL) {
        NSApp.activate(ignoringOtherApps: true)

        let options = availableBrowserOptions().filter { !$0.isHidden }
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
                let summary = URLLogSummary(url: url)
                appDelegateLogger.info("BrowserRouter chooser selected option \(option.id, privacy: .public) for \(summary.description, privacy: .public)")
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
                    self?.openSettings()
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
                },
                onRestoreDefaultBrowser: { [weak self] in
                    self?.confirmAndRestorePreviousDefaultBrowser()
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

    private func restoreDefaultBrowserCandidate() -> SavedDefaultBrowser? {
        if let previousDefaultBrowser = configuration.previousDefaultBrowser {
            return previousDefaultBrowser
        }

        guard let option = configuration.browserOptions.first(where: { $0.id == configuration.defaultOptionID }) else {
            return nil
        }

        return SavedDefaultBrowser(
            bundleIdentifier: option.bundleIdentifier,
            displayName: option.appName ?? option.name,
            appName: option.appName
        )
    }

    private func confirmAndRestorePreviousDefaultBrowser() {
        refreshConfigurationIfNeeded()

        guard let target = restoreDefaultBrowserCandidate() else {
            showMessage(
                title: "No Previous Default Browser",
                message: "BrowserRouter does not have a saved previous default browser. Choose another default browser in macOS System Settings."
            )
            return
        }

        guard let manager = currentDefaultBrowserManager(forceReload: true) else {
            showMessage(
                title: "Could Not Restore Default Browser",
                message: "BrowserRouter could not initialize its default-handler manager."
            )
            return
        }

        let alert = NSAlert()
        alert.messageText = "Restore Previous Default Browser?"
        alert.informativeText = "This will set both http and https links to open with \(target.displayName) instead of BrowserRouter."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        Task { @MainActor in
            do {
                try await manager.restoreDefaultBrowser(to: target)
                appDelegateLogger.info("BrowserRouter restored default browser to \(target.bundleIdentifier, privacy: .public)")
                showMessage(
                    title: "Default Browser Restored",
                    message: "\(target.displayName) now handles http and https links. BrowserRouter can still be opened from /Applications."
                )
                settingsWindowController?.reload(with: configuration)
                onboardingWindowController?.reload(with: configuration, isRoutingToSelf: manager.isRoutingToSelf())
            } catch {
                appDelegateLogger.error("BrowserRouter failed to restore default browser to \(target.bundleIdentifier, privacy: .public): \(String(describing: error), privacy: .public)")
                showMessage(
                    title: "Could Not Restore Default Browser",
                    message: "\(error.localizedDescription)\n\nCurrent handlers:\n\(manager.statusSummary())"
                )
            }
        }
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
