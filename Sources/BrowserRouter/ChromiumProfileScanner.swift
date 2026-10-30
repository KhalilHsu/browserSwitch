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

    static func detectedOptions(existingOptions: [BrowserOption] = []) -> [BrowserOption] {
        scan(existingOptions: existingOptions).options
    }

    /// Finds every profile of each installed Chromium browser.
    ///
    /// `Local State` is the source of truth (it has the display names), but since macOS 27 the
    /// browser's Application Support folder is protected and unreadable without Full Disk Access.
    /// The profile folders under ~/Library/Caches are not protected, so they are used to still find
    /// every profile; names then come from earlier scans, falling back to the folder name.
    static func scan(existingOptions: [BrowserOption] = []) -> ProfileScanResult {
        specs.reduce(into: ProfileScanResult()) { result, spec in
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: spec.bundleIdentifier) != nil else {
                return
            }

            let profiles = profiles(for: spec, existingOptions: existingOptions)
            result.options += profiles.entries.map { profile in
                BrowserOption(
                    id: "\(spec.idPrefix)-\(BrowserSlug.makeProfileIDComponent(profile.directory))",
                    name: "\(spec.optionNamePrefix) - \(profile.displayName)",
                    bundleIdentifier: spec.bundleIdentifier,
                    appName: spec.appName,
                    profileDirectory: profile.directory,
                    extraArguments: nil
                )
            }
            if profiles.hasMissingNames {
                result.appsMissingProfileNames.append(spec.appName)
            }
        }
    }

    static func mergeDetectedOptions(into configuration: RouterConfiguration) -> RouterConfiguration {
        ProfileScanSupport.merge(detectedOptions(existingOptions: configuration.browserOptions), into: configuration)
    }

    private static func profiles(
        for spec: ChromiumAppSpec,
        existingOptions: [BrowserOption]
    ) -> (entries: [(directory: String, displayName: String)], hasMissingNames: Bool) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let root = home.appendingPathComponent(spec.supportSubpath)

        let localState = ProfileScanSupport.read(root.appendingPathComponent("Local State"), parse: profileNames(fromLocalState:))
        if case .value(let names) = localState, !names.isEmpty {
            return (sortedEntries(names), false)
        }

        // Union of profile folders from the user data dir (readable before macOS 27) and the cache dir.
        var directories = Set<String>()
        if case .value(let names) = ProfileScanSupport.subdirectoryNames(of: root) {
            directories.formUnion(names.filter(isProfileDirectoryName))
        }
        if case .value(let names) = ProfileScanSupport.subdirectoryNames(of: home.appendingPathComponent(cacheSubpath(for: spec))) {
            directories.formUnion(names.filter(isProfileDirectoryName))
        }

        let knownNames = Dictionary(
            existingOptions.compactMap { option -> (String, String)? in
                guard option.bundleIdentifier == spec.bundleIdentifier, let directory = option.profileDirectory else {
                    return nil
                }
                return (directory, profileName(fromOptionName: option.name, spec: spec))
            },
            uniquingKeysWith: { first, _ in first }
        )

        var names: [String: String] = [:]
        var hasMissingNames = false
        for directory in directories {
            if let known = knownNames[directory], known != directory {
                names[directory] = known
            } else {
                names[directory] = directory
                if case .permissionDenied = localState {
                    hasMissingNames = true
                }
            }
        }
        return (sortedEntries(names), hasMissingNames)
    }

    /// Maps profile folder names to display names from `Local State` → `profile.info_cache`.
    private static func profileNames(fromLocalState data: Data) -> [String: String]? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let profile = json["profile"] as? [String: Any],
            let infoCache = profile["info_cache"] as? [String: Any]
        else {
            return nil
        }

        var names: [String: String] = [:]
        for (directory, value) in infoCache {
            let name = (value as? [String: Any])?["name"] as? String
            names[directory] = name.flatMap { $0.isEmpty ? nil : $0 } ?? directory
        }
        return names
    }

    private static func cacheSubpath(for spec: ChromiumAppSpec) -> String {
        spec.supportSubpath.replacingOccurrences(of: "Library/Application Support/", with: "Library/Caches/")
    }

    /// Real profiles are `Default` and `Profile N`; `System Profile` and `Guest Profile` are internal.
    private static func isProfileDirectoryName(_ name: String) -> Bool {
        name == "Default" || (name.hasPrefix("Profile ") && Int(name.dropFirst("Profile ".count)) != nil)
    }

    private static func profileName(fromOptionName name: String, spec: ChromiumAppSpec) -> String {
        let prefix = "\(spec.optionNamePrefix) - "
        return name.hasPrefix(prefix) ? String(name.dropFirst(prefix.count)) : name
    }

    private static func sortedEntries(_ names: [String: String]) -> [(directory: String, displayName: String)] {
        names
            .map { (directory: $0.key, displayName: $0.value) }
            .sorted { $0.directory.localizedStandardCompare($1.directory) == .orderedAscending }
    }
}
