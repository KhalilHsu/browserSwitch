import AppKit
import CoreGraphics
import Foundation
import BrowserRouterCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var configuration = RouterConfiguration.load()
    private let launcher = BrowserLauncher()
    private var settingsWindowController: SettingsWindowController?
    private var chooserWindowController: BrowserChooserWindowController?
    private var defaultBrowserManager: DefaultBrowserManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        defaultBrowserManager = try? DefaultBrowserManager()
        configuration = cleanupGhostBrowsersIfNeeded()
        installStatusItem()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            handle(url)
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Router"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Set as HTTP/HTTPS Default", action: #selector(setAsDefaultBrowser), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show Default Handler Status", action: #selector(showDefaultHandlerStatus), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Open Config", action: #selector(openConfig), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show Test Chooser", action: #selector(showTestChooser), keyEquivalent: "t"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func handle(_ url: URL) {
        configuration = RouterConfiguration.load()

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
            onSelect: { [weak self] option in
                NSLog("BrowserRouter chooser selected option \(option.id) for \(url.absoluteString)")
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

    @objc private func setAsDefaultBrowser() {
        Task { @MainActor in
            do {
                let manager = try DefaultBrowserManager()
                defaultBrowserManager = manager

                guard manager.isInstalledInApplications() else {
                    showMessage(
                        title: "Install BrowserRouter First",
                        message: "Move BrowserRouter.app into /Applications before setting it as the default browser. The new scripts/install.sh command does this for you."
                    )
                    return
                }

                try await manager.setAsDefaultBrowser()
                NSLog("BrowserRouter default handler set successfully:\n\(manager.statusSummary())")
                showMessage(
                    title: "BrowserRouter Is Now The Default",
                    message: manager.statusSummary()
                )
            } catch {
                NSLog("BrowserRouter failed to become the default browser: \(error)")
                showMessage(
                    title: "Could Not Set BrowserRouter As Default",
                    message: "\(error.localizedDescription)\n\nCurrent handlers:\n\((try? DefaultBrowserManager().statusSummary()) ?? "Unavailable")"
                )
            }
        }
    }

    @objc private func showDefaultHandlerStatus() {
        let summary = defaultBrowserManager?.statusSummary()
            ?? (try? DefaultBrowserManager().statusSummary())
            ?? "Unavailable"
        showMessage(title: "Default Handler Status", message: summary)
    }

    @objc private func openConfig() {
        _ = RouterConfiguration.load()
        NSWorkspace.shared.open(RouterConfiguration.configURL)
    }

    @objc private func openSettings() {
        configuration = cleanupGhostBrowsersIfNeeded()

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(configuration: configuration) { [weak self] newConfiguration in
                self?.configuration = newConfiguration
            }
        } else {
            settingsWindowController?.reload(with: configuration)
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showTestChooser() {
        showChooser(for: URL(string: "https://example.com")!)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
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
            NSLog("BrowserRouter failed to persist browser cleanup: \(error)")
        }

        return result.configuration
    }
}