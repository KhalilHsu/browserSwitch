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

    static func detectedOptions(existingOptions: [BrowserOption] = []) -> [BrowserOption] {
        scan(existingOptions: existingOptions).options
    }

    /// Reads `profiles.ini`. Since macOS 27 the Firefox support folder needs Full Disk Access, so when
    /// it is blocked the profile folders under ~/Library/Caches/Firefox/Profiles are used instead and
    /// launched by path, since their `-P` names are unknown.
    static func scan(existingOptions: [BrowserOption] = []) -> ProfileScanResult {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil else {
            return ProfileScanResult()
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let root = home.appendingPathComponent(supportSubpath)
        let profilesINI = ProfileScanSupport.read(root.appendingPathComponent("profiles.ini")) { data in
            String(data: data, encoding: .utf8).map(profiles(fromINI:))
        }

        if case .value(let profiles) = profilesINI, !profiles.isEmpty {
            return ProfileScanResult(options: profiles.map { profile in
                option(id: profile.path, name: profile.name, arguments: ["-P", profile.name])
            })
        }

        guard case .permissionDenied = profilesINI,
              case .value(let folders) = ProfileScanSupport.subdirectoryNames(of: home.appendingPathComponent("Library/Caches/Firefox/Profiles"))
        else {
            return ProfileScanResult()
        }

        var hasMissingNames = false
        let options = folders.sorted().map { folder -> BrowserOption in
            let path = "Profiles/\(folder)"
            let id = "firefox-\(BrowserSlug.makeProfileIDComponent(path))"
            let name = existingOptions.first { $0.id == id }?.name.replacingOccurrences(of: "Firefox - ", with: "")
            if name == nil {
                hasMissingNames = true
            }
            return option(
                id: path,
                name: name ?? folder,
                arguments: ["-profile", root.appendingPathComponent(path).path]
            )
        }
        return ProfileScanResult(options: options, appsMissingProfileNames: hasMissingNames ? [appName] : [])
    }

    static func mergeDetectedOptions(into configuration: RouterConfiguration) -> RouterConfiguration {
        ProfileScanSupport.merge(detectedOptions(existingOptions: configuration.browserOptions), into: configuration)
    }

    private static func option(id path: String, name: String, arguments: [String]) -> BrowserOption {
        BrowserOption(
            id: "firefox-\(BrowserSlug.makeProfileIDComponent(path))",
            name: "Firefox - \(name)",
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            profileDirectory: path,
            extraArguments: arguments
        )
    }

    private static func profiles(fromINI contents: String) -> [FirefoxProfile] {
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
