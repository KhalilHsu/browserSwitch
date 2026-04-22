import AppKit
import Foundation
import OSLog
import BrowserRouterCore

private let browserLauncherLogger = Logger(subsystem: "local.browser-router", category: "browser-launcher")

final class BrowserLauncher {
    func isInstalled(_ option: BrowserOption) -> Bool {
        BrowserAvailability.isInstalled(option)
    }

    func open(_ url: URL, with option: BrowserOption) {
        browserLauncherLogger.info("BrowserRouter opening \(url.absoluteString, privacy: .public) with option \(option.id, privacy: .public)")
        if let profileDirectory = option.profileDirectory, isChromium(option) {
            openChromium(url, option: option, profileDirectory: profileDirectory)
            return
        }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: option.bundleIdentifier) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
                if let error {
                    browserLauncherLogger.error("BrowserRouter failed to open \(url.absoluteString, privacy: .public) with \(option.name, privacy: .public): \(String(describing: error), privacy: .public)")
                }
            }
            return
        }

        openFallback(url)
    }

    private func isChromium(_ option: BrowserOption) -> Bool {
        Self.chromiumBundleIdentifiers.contains(option.bundleIdentifier.lowercased())
    }

    private static let chromiumBundleIdentifiers: Set<String> = [
        "com.google.chrome",
        "com.google.chrome.canary",
        "com.microsoft.edgemac",
        "com.brave.browser",
        "com.vivaldi.vivaldi"
    ]

    private func openChromium(_ url: URL, option: BrowserOption, profileDirectory: String) {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: option.bundleIdentifier) != nil else {
            openFallback(url)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")

        var arguments = ["-na"]
        if let appName = option.appName {
            arguments.append(appName)
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: option.bundleIdentifier) {
            arguments.append(appURL.path)
        }

        arguments.append("--args")
        arguments.append("--profile-directory=\(profileDirectory)")
        arguments.append(contentsOf: option.extraArguments ?? [])
        arguments.append(url.absoluteString)
        process.arguments = arguments

        do {
            try process.run()
        } catch {
            browserLauncherLogger.error("BrowserRouter chromium launch failed: \(String(describing: error), privacy: .public)")
            openFallback(url)
        }
    }

    private func openFallback(_ url: URL) {
        guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") else {
            browserLauncherLogger.error("BrowserRouter fallback failed: Safari is not available")
            return
        }

        NSWorkspace.shared.open([url], withApplicationAt: safariURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                browserLauncherLogger.error("BrowserRouter Safari fallback failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
