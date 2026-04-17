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

struct StaticBrowserSpec {
    var id: String
    var name: String
    var bundleIdentifier: String
    var appName: String?
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
    static let staticSpecs = [
        StaticBrowserSpec(
            id: "arc-default",
            name: "Arc",
            bundleIdentifier: "company.thebrowser.Browser",
            appName: "Arc"
        ),
        StaticBrowserSpec(
            id: "safari",
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            appName: "Safari"
        ),
        StaticBrowserSpec(
            id: "firefox-default",
            name: "Firefox",
            bundleIdentifier: "org.mozilla.firefox",
            appName: "Firefox"
        )
    ]

    static func detectedStaticOptions() -> [BrowserOption] {
        staticSpecs.compactMap { spec in
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: spec.bundleIdentifier) != nil else {
                return nil
            }

            return BrowserOption(
                id: spec.id,
                name: spec.name,
                bundleIdentifier: spec.bundleIdentifier,
                appName: spec.appName,
                profileDirectory: nil,
                extraArguments: nil
            )
        }
    }

    static func refreshConfiguration(_ configuration: RouterConfiguration) -> BrowserRefreshResult {
        let unavailableOptions = configuration.browserOptions.filter { !BrowserAvailability.isInstalled($0) }
        var mergedByID = Dictionary(
            uniqueKeysWithValues: BrowserAvailability.installedOptions(from: configuration.browserOptions).map { ($0.id, $0) }
        )

        let detectedOptions = detectedStaticOptions() + ChromiumProfileScanner.detectedOptions()
        for option in detectedOptions {
            mergedByID[option.id] = option
        }

        let originalIDs = configuration.browserOptions.map(\.id)
        let detectedIDs = detectedOptions.map(\.id).filter { !originalIDs.contains($0) }
        let mergedIDs = originalIDs.filter { mergedByID[$0] != nil } + detectedIDs
        let mergedOptions = mergedIDs.compactMap { mergedByID[$0] }

        let availableIDs = Set(mergedOptions.map(\.id))
        let unresolvedRuleCount = configuration.routingRules.filter { !availableIDs.contains($0.browserOptionID) }.count
        let resolvedDefaultID = availableIDs.contains(configuration.defaultOptionID)
            ? configuration.defaultOptionID
            : mergedOptions.first?.id ?? configuration.defaultOptionID

        let addedOptionNames = detectedIDs.compactMap { mergedByID[$0]?.name }

        return BrowserRefreshResult(
            configuration: RouterConfiguration(
                defaultOptionID: resolvedDefaultID,
                chooserModifier: configuration.chooserModifier,
                showsDockIcon: configuration.showsDockIcon,
                showsStatusItem: configuration.showsStatusItem,
                browserOptions: mergedOptions,
                routingRules: configuration.routingRules
            ),
            removedUnavailableOptionNames: unavailableOptions.map(\.name),
            addedOptionNames: addedOptionNames,
            unresolvedRuleCount: unresolvedRuleCount
        )
    }
}
