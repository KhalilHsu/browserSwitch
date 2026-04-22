import AppKit
import Foundation
import BrowserRouterCore

struct ChromiumAppSpec {
    var idPrefix: String
    var optionNamePrefix: String
    var bundleIdentifier: String
    var appName: String
    var supportSubpath: String
}

enum ChromiumProfileScanner {
    static let specs = [
        ChromiumAppSpec(
            idPrefix: "chrome",
            optionNamePrefix: "Chrome",
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            supportSubpath: "Library/Application Support/Google/Chrome"
        ),
        ChromiumAppSpec(
            idPrefix: "chrome-canary",
            optionNamePrefix: "Chrome Canary",
            bundleIdentifier: "com.google.Chrome.canary",
            appName: "Google Chrome Canary",
            supportSubpath: "Library/Application Support/Google/Chrome Canary"
        ),
        ChromiumAppSpec(
            idPrefix: "edge",
            optionNamePrefix: "Edge",
            bundleIdentifier: "com.microsoft.edgemac",
            appName: "Microsoft Edge",
            supportSubpath: "Library/Application Support/Microsoft Edge"
        ),
        ChromiumAppSpec(
            idPrefix: "brave",
            optionNamePrefix: "Brave",
            bundleIdentifier: "com.brave.Browser",
            appName: "Brave Browser",
            supportSubpath: "Library/Application Support/BraveSoftware/Brave-Browser"
        ),
        ChromiumAppSpec(
            idPrefix: "vivaldi",
            optionNamePrefix: "Vivaldi",
            bundleIdentifier: "com.vivaldi.Vivaldi",
            appName: "Vivaldi",
            supportSubpath: "Library/Application Support/Vivaldi"
        )
    ]

    static func detectedOptions() -> [BrowserOption] {
        specs.flatMap { spec -> [BrowserOption] in
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: spec.bundleIdentifier) != nil else {
                return []
            }

            return profileDirectories(for: spec).map { profile in
                BrowserOption(
                    id: "\(spec.idPrefix)-\(BrowserSlug.makeProfileIDComponent(profile.directory))",
                    name: "\(spec.optionNamePrefix) - \(profile.displayName)",
                    bundleIdentifier: spec.bundleIdentifier,
                    appName: spec.appName,
                    profileDirectory: profile.directory,
                    extraArguments: nil
                )
            }
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
            browserOptions: mergedOptions,
            routingRules: configuration.routingRules
        )
    }

    private static func profileDirectories(for spec: ChromiumAppSpec) -> [(directory: String, displayName: String)] {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(spec.supportSubpath)
        let localStateURL = root.appendingPathComponent("Local State")

        if let profiles = profilesFromLocalState(localStateURL) {
            return profiles
        }

        let discovered = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return discovered.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return nil
            }

            let directory = url.lastPathComponent
            guard directory == "Default" || directory.hasPrefix("Profile ") else {
                return nil
            }

            return (directory: directory, displayName: directory)
        }.sorted { $0.directory.localizedStandardCompare($1.directory) == .orderedAscending }
    }

    private static func profilesFromLocalState(_ url: URL) -> [(directory: String, displayName: String)]? {
        guard
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let profile = json["profile"] as? [String: Any],
            let infoCache = profile["info_cache"] as? [String: Any]
        else {
            return nil
        }

        let profiles = infoCache.compactMap { directory, value -> (directory: String, displayName: String)? in
            guard let info = value as? [String: Any] else {
                return nil
            }

            let name = info["name"] as? String
            let displayName = if let name, !name.isEmpty {
                name
            } else {
                directory
            }
            return (directory: directory, displayName: displayName)
        }

        return profiles.sorted { $0.directory.localizedStandardCompare($1.directory) == .orderedAscending }
    }
}
