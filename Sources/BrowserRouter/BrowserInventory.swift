import AppKit
import Foundation
import BrowserRouterCore

enum BrowserAvailability {
    static func isInstalled(_ option: BrowserOption) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: option.bundleIdentifier) != nil
    }

    static func installedOptions(from options: [BrowserOption]) -> [BrowserOption] {
        options.filter(isInstalled)
    }
}

struct BrowserRefreshResult {
    var configuration: RouterConfiguration
    var removedUnavailableOptionNames: [String]
    var addedOptionNames: [String]
    var unresolvedRuleCount: Int

    var changed: Bool {
        !removedUnavailableOptionNames.isEmpty || !addedOptionNames.isEmpty
    }

    var statusMessage: String {
        var parts: [String] = []
        if !addedOptionNames.isEmpty {
            parts.append("added \(addedOptionNames.count)")
        }
        if !removedUnavailableOptionNames.isEmpty {
            parts.append("removed \(removedUnavailableOptionNames.count)")
        }
        if unresolvedRuleCount > 0 {
            parts.append("\(unresolvedRuleCount) rule(s) still need attention")
        }
        return parts.isEmpty ? "Browsers already up to date" : "Browsers refreshed: " + parts.joined(separator: ", ")
    }
}

enum BrowserInventory {
    static func refreshConfiguration(_ configuration: RouterConfiguration) -> BrowserRefreshResult {
        let unavailableOptions = configuration.browserOptions.filter { !BrowserAvailability.isInstalled($0) }
        let installedExistingOptions = BrowserAvailability.installedOptions(from: configuration.browserOptions)
        let profileOptions = ChromiumProfileScanner.detectedOptions() + FirefoxProfileScanner.detectedOptions()
        let profileBundleIdentifiers = Set(profileOptions.map(\.bundleIdentifier))
        let systemOptions = detectedSystemHandlerOptions(existingOptions: installedExistingOptions).filter { option in
            !profileBundleIdentifiers.contains(option.bundleIdentifier)
        }
        let detectedOptions = systemOptions + profileOptions

        var mergedByID = Dictionary(uniqueKeysWithValues: installedExistingOptions.map { ($0.id, $0) })
        for option in systemOptions {
            mergedByID[option.id] = option
        }
        for option in profileOptions {
            mergedByID[option.id] = option
        }

        for existing in configuration.browserOptions {
            if var merged = mergedByID[existing.id] {
                merged.isHidden = existing.isHidden
                mergedByID[existing.id] = merged
            }
        }

        let originalIDs = configuration.browserOptions.map(\.id)
        let detectedIDs = detectedOptions.map(\.id)
        
        let validOriginalIDs = originalIDs.filter { id in
            guard let option = mergedByID[id] else { return false }
            return detectedIDs.contains(id) || option.profileDirectory != nil
        }
        let newIDs = detectedIDs.filter { !originalIDs.contains($0) }
        let mergedIDs = validOriginalIDs + newIDs
        
        let mergedOptions = mergedIDs.compactMap { mergedByID[$0] }

        let availableIDs = Set(mergedOptions.map(\.id))
        let unresolvedRuleCount = configuration.routingRules.filter { !availableIDs.contains($0.browserOptionID) }.count
        let previousDefaultOption = configuration.browserOptions.first { $0.id == configuration.defaultOptionID }
        let replacementDefaultID = previousDefaultOption.flatMap { previousOption in
            mergedOptions.first { $0.bundleIdentifier == previousOption.bundleIdentifier }?.id
        }
        let resolvedDefaultID = availableIDs.contains(configuration.defaultOptionID)
            ? configuration.defaultOptionID
            : replacementDefaultID ?? mergedOptions.first?.id ?? configuration.defaultOptionID

        let addedOptionNames = detectedIDs.compactMap { mergedByID[$0]?.name }

        return BrowserRefreshResult(
            configuration: RouterConfiguration(
                defaultOptionID: resolvedDefaultID,
                chooserModifier: configuration.chooserModifier,
                showsDockIcon: configuration.showsDockIcon,
                showsStatusItem: configuration.showsStatusItem,
                hasCompletedOnboarding: configuration.hasCompletedOnboarding,
                autoRestoreDefaultBrowserOnQuit: configuration.autoRestoreDefaultBrowserOnQuit,
                previousDefaultBrowser: configuration.previousDefaultBrowser,
                browserOptions: mergedOptions,
                routingRules: configuration.routingRules
            ),
            removedUnavailableOptionNames: unavailableOptions.map(\.name),
            addedOptionNames: addedOptionNames,
            unresolvedRuleCount: unresolvedRuleCount
        )
    }

    private static func detectedSystemHandlerOptions(existingOptions: [BrowserOption]) -> [BrowserOption] {
        let routerBundleIdentifiers = Set([
            Bundle.main.bundleIdentifier,
            "local.browser-router"
        ].compactMap { $0 })
        let handlerBundleIdentifiers = allURLHandlerBundleIdentifiers()
        var seenDisplayNames = Set<String>()

        var options: [BrowserOption] = []
        for bundleIdentifier in handlerBundleIdentifiers {
            guard !routerBundleIdentifiers.contains(bundleIdentifier) else {
                continue
            }

            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                continue
            }

            let bundle = Bundle(url: appURL)
            let displayName = bundleDisplayName(bundle, fallback: bundleIdentifier)
            guard !seenDisplayNames.contains(displayName) else {
                continue
            }
            seenDisplayNames.insert(displayName)

            let appName = bundleName(bundle)
                ?? displayName
            let id = existingAppOptionID(for: bundleIdentifier, in: existingOptions)
                ?? "system-\(BrowserSlug.make(bundleIdentifier))"

            options.append(BrowserOption(
                id: id,
                name: displayName,
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                profileDirectory: nil,
                extraArguments: nil
            ))
        }

        return options
    }

    private static func allURLHandlerBundleIdentifiers() -> [String] {
        var seen = Set<String>()
        var bundleIdentifiers: [String] = []

        for scheme in ["http", "https"] {
            guard let url = URL(string: "\(scheme)://example.com") else {
                continue
            }

            let handlers = NSWorkspace.shared.urlsForApplications(toOpen: url)
                .compactMap { Bundle(url: $0)?.bundleIdentifier }
            for bundleIdentifier in handlers where !seen.contains(bundleIdentifier) {
                seen.insert(bundleIdentifier)
                bundleIdentifiers.append(bundleIdentifier)
            }
        }

        return bundleIdentifiers
    }

    private static func existingAppOptionID(for bundleIdentifier: String, in options: [BrowserOption]) -> String? {
        options.first {
            $0.bundleIdentifier == bundleIdentifier && $0.profileDirectory == nil
        }?.id
    }

    private static func bundleDisplayName(_ bundle: Bundle?, fallback: String) -> String {
        bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.localizedInfoDictionary?["CFBundleName"] as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? fallback
    }

    private static func bundleName(_ bundle: Bundle?) -> String? {
        bundle?.localizedInfoDictionary?["CFBundleName"] as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
    }

}
