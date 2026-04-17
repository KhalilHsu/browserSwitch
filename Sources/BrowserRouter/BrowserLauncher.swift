import AppKit
import Foundation
import BrowserRouterCore

final class BrowserLauncher {
    func isInstalled(_ option: BrowserOption) -> Bool {
        BrowserAvailability.isInstalled(option)
    }

    func open(_ url: URL, with option: BrowserOption) {
        NSLog("BrowserRouter opening \(url.absoluteString) with option \(option.id)")
        if let profileDirectory = option.profileDirectory, isChromium(option) {
            openChromium(url, option: option, profileDirectory: profileDirectory)
            return
        }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: option.bundleIdentifier) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
                if let error {
                    NSLog("BrowserRouter failed to open \(url) with \(option.name): \(error)")
                }
            }
            return
        }

        openFallback(url)
    }

    private func isChromium(_ option: BrowserOption) -> Bool {
        let bundle = option.bundleIdentifier.lowercased()
        return bundle.contains("chrome")
            || bundle.contains("edge")
            || bundle.contains("brave")
            || bundle.contains("vivaldi")
            || bundle.contains("browser")
    }

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
            NSLog("BrowserRouter chromium launch failed: \(error)")
            openFallback(url)
        }
    }

    private func openFallback(_ url: URL) {
        guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") else {
            NSLog("BrowserRouter fallback failed: Safari is not available")
            return
        }

        NSWorkspace.shared.open([url], withApplicationAt: safariURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                NSLog("BrowserRouter Safari fallback failed: \(error)")
            }
        }
    }
}