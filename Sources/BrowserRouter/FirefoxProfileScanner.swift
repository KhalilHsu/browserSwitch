import AppKit
import Foundation
import BrowserRouterCore

private struct FirefoxProfile {
    var name: String
    var path: String
}

enum FirefoxProfileScanner {
    private static let bundleIdentifier = "org.mozilla.firefox"
    private static let appName = "Firefox"
    private static let supportSubpath = "Library/Application Support/Firefox"

    static func detectedOptions() -> [BrowserOption] {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil else {
            return []
        }

        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(supportSubpath)
        let profilesURL = root.appendingPathComponent("profiles.ini")
        return profiles(from: profilesURL).map { profile in
            BrowserOption(
                id: "firefox-\(BrowserSlug.makeProfileIDComponent(profile.path))",
                name: "Firefox - \(profile.name)",
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                profileDirectory: profile.path,
                extraArguments: ["-P", profile.name]
            )
        }
    }

    static func mergeDetectedOptions(into configuration: RouterConfiguration) -> RouterConfiguration {
        let detected = detectedOptions()
        guard !detected.isEmpty else {
            return configuration
        }

        var byID = Dictionary(uniqueKeysWithValues: configuration.browserOptions.map { ($0.id, $0) })
        for option in detected {
            byID[option.id] = option
        }

        let originalIDs = configuration.browserOptions.map(\.id)
        let detectedIDs = detected.map(\.id).filter { !originalIDs.contains($0) }
        let orderedIDs = originalIDs + detectedIDs
        let mergedOptions = orderedIDs.compactMap { byID[$0] }

        return RouterConfiguration(
            defaultOptionID: configuration.defaultOptionID,
            chooserModifier: configuration.chooserModifier,
            showsDockIcon: configuration.showsDockIcon,
            showsStatusItem: configuration.showsStatusItem,
            hasCompletedOnboarding: configuration.hasCompletedOnboarding,
            previousDefaultBrowser: configuration.previousDefaultBrowser,
            browserOptions: mergedOptions,
            routingRules: configuration.routingRules
        )
    }

    private static func profiles(from url: URL) -> [FirefoxProfile] {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        var sections: [[String: String]] = []
        var current: [String: String] = [:]

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix(";"), !line.hasPrefix("#") else {
                continue
            }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                if !current.isEmpty {
                    sections.append(current)
                }
                current = [:]
                continue
            }

            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else {
                continue
            }

            current[parts[0].trimmingCharacters(in: .whitespacesAndNewlines)] =
                parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !current.isEmpty {
            sections.append(current)
        }

        return sections.compactMap { section in
            guard let path = section["Path"], !path.isEmpty else {
                return nil
            }

            let fallbackName = URL(fileURLWithPath: path).lastPathComponent
            let name = section["Name"].flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
            return FirefoxProfile(name: name, path: path)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
