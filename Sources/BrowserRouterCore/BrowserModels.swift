import Foundation
import OSLog

private let configurationLogger = Logger(subsystem: "local.browser-router", category: "configuration")

public struct BrowserOption: Codable, Hashable {
    public var id: String
    public var name: String
    public var bundleIdentifier: String
    public var appName: String?
    public var profileDirectory: String?
    public var extraArguments: [String]?

    public init(
        id: String,
        name: String,
        bundleIdentifier: String,
        appName: String?,
        profileDirectory: String?,
        extraArguments: [String]?
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.profileDirectory = profileDirectory
        self.extraArguments = extraArguments
    }
}

public struct RoutingRule: Codable, Hashable {
    public var id: String
    public var name: String
    public var isEnabled: Bool
    public var browserOptionID: String
    public var hostContains: String?
    public var hostSuffix: String?
    public var pathPrefix: String?
    public var urlContains: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isEnabled
        case browserOptionID
        case hostContains
        case hostSuffix
        case pathPrefix
        case urlContains
    }

    public init(
        id: String,
        name: String,
        isEnabled: Bool = true,
        browserOptionID: String,
        hostContains: String?,
        hostSuffix: String?,
        pathPrefix: String?,
        urlContains: String?
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.browserOptionID = browserOptionID
        self.hostContains = hostContains
        self.hostSuffix = hostSuffix
        self.pathPrefix = pathPrefix
        self.urlContains = urlContains
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        browserOptionID = try container.decode(String.self, forKey: .browserOptionID)
        hostContains = try container.decodeIfPresent(String.self, forKey: .hostContains)
        hostSuffix = try container.decodeIfPresent(String.self, forKey: .hostSuffix)
        pathPrefix = try container.decodeIfPresent(String.self, forKey: .pathPrefix)
        urlContains = try container.decodeIfPresent(String.self, forKey: .urlContains)
    }
}

public struct SavedDefaultBrowser: Codable, Hashable {
    public var bundleIdentifier: String
    public var displayName: String
    public var appName: String?

    public init(
        bundleIdentifier: String,
        displayName: String,
        appName: String?
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.appName = appName
    }
}

public struct RouterConfiguration: Codable {
    public var defaultOptionID: String
    public var chooserModifier: String
    /// Raw value of CGEventFlags for a user-recorded custom chooser shortcut.
    /// Only used when chooserModifier == "custom".
    public var customChooserFlags: UInt64?
    /// Optional key code for a letter/number key that is part of the custom shortcut.
    /// nil means the shortcut is modifier-keys only.
    public var customChooserKeyCode: Int?
    public var showsDockIcon: Bool
    public var showsStatusItem: Bool
    public var hasCompletedOnboarding: Bool
    public var previousDefaultBrowser: SavedDefaultBrowser?
    public var browserOptions: [BrowserOption]
    public var routingRules: [RoutingRule]

    enum CodingKeys: String, CodingKey {
        case defaultOptionID
        case chooserModifier
        case customChooserFlags
        case customChooserKeyCode
        case showsDockIcon
        case showsStatusItem
        case hasCompletedOnboarding
        case previousDefaultBrowser
        case browserOptions
        case routingRules
    }

    public init(
        defaultOptionID: String,
        chooserModifier: String,
        customChooserFlags: UInt64? = nil,
        customChooserKeyCode: Int? = nil,
        showsDockIcon: Bool = false,
        showsStatusItem: Bool = true,
        hasCompletedOnboarding: Bool = false,
        previousDefaultBrowser: SavedDefaultBrowser? = nil,
        browserOptions: [BrowserOption],
        routingRules: [RoutingRule] = []
    ) {
        self.defaultOptionID = defaultOptionID
        self.chooserModifier = chooserModifier
        self.customChooserFlags = customChooserFlags
        self.customChooserKeyCode = customChooserKeyCode
        self.showsDockIcon = showsDockIcon
        self.showsStatusItem = showsStatusItem
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.previousDefaultBrowser = previousDefaultBrowser
        self.browserOptions = browserOptions
        self.routingRules = routingRules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultOptionID = try container.decode(String.self, forKey: .defaultOptionID)
        chooserModifier = try container.decodeIfPresent(String.self, forKey: .chooserModifier) ?? "command+shift"
        customChooserFlags = try container.decodeIfPresent(UInt64.self, forKey: .customChooserFlags)
        customChooserKeyCode = try container.decodeIfPresent(Int.self, forKey: .customChooserKeyCode)
        showsDockIcon = try container.decodeIfPresent(Bool.self, forKey: .showsDockIcon) ?? false
        showsStatusItem = try container.decodeIfPresent(Bool.self, forKey: .showsStatusItem) ?? true
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? true
        previousDefaultBrowser = try container.decodeIfPresent(SavedDefaultBrowser.self, forKey: .previousDefaultBrowser)
        browserOptions = try container.decode([BrowserOption].self, forKey: .browserOptions)
        routingRules = try container.decodeIfPresent([RoutingRule].self, forKey: .routingRules) ?? []
    }

    public static let supportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("BrowserRouter", isDirectory: true)
    }()

    public static let configURL = supportDirectory.appendingPathComponent("config.json")

    public static func load() -> RouterConfiguration {
        do {
            try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: configURL.path) {
                let data = try Data(contentsOf: configURL)
                return try JSONDecoder().decode(RouterConfiguration.self, from: data)
            }

            let config = RouterConfiguration.sample()
            try config.save()
            return config
        } catch {
            configurationLogger.error("BrowserRouter config load failed: \(String(describing: error), privacy: .public)")
            return .sample()
        }
    }

    public func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        let tempURL = Self.configURL.deletingLastPathComponent()
            .appendingPathComponent(".config.json.\(UUID().uuidString).tmp")
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            let created = FileManager.default.createFile(
                atPath: tempURL.path,
                contents: data,
                attributes: [.posixPermissions: NSNumber(value: 0o600)]
            )
            guard created else {
                throw CocoaError(.fileWriteUnknown)
            }
            if FileManager.default.fileExists(atPath: Self.configURL.path) {
                try FileManager.default.removeItem(at: Self.configURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: Self.configURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }

    public mutating func adoptDefaultBrowser(
        bundleIdentifier: String,
        displayName: String,
        appName: String?
    ) {
        previousDefaultBrowser = SavedDefaultBrowser(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            appName: appName
        )

        let existingOption = browserOptions.first {
            $0.bundleIdentifier == bundleIdentifier && ($0.profileDirectory == "Default" || $0.id.hasSuffix("-default"))
        } ?? browserOptions.first {
            $0.bundleIdentifier == bundleIdentifier && $0.profileDirectory == nil
        } ?? browserOptions.first(where: { $0.bundleIdentifier == bundleIdentifier })

        if let existingOption {
            defaultOptionID = existingOption.id
            return
        }

        let optionID = uniqueBrowserOptionID(prefix: "previous-default-\(BrowserSlug.make(bundleIdentifier))")
        browserOptions.insert(
            BrowserOption(
                id: optionID,
                name: displayName,
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                profileDirectory: nil,
                extraArguments: nil
            ),
            at: 0
        )
        defaultOptionID = optionID
    }

    private func uniqueBrowserOptionID(prefix: String) -> String {
        let existingIDs = Set(browserOptions.map(\.id))
        guard existingIDs.contains(prefix) else {
            return prefix
        }

        var suffix = 2
        while existingIDs.contains("\(prefix)-\(suffix)") {
            suffix += 1
        }
        return "\(prefix)-\(suffix)"
    }

    public static func sample() -> RouterConfiguration {
        RouterConfiguration(
            defaultOptionID: "arc-default",
            chooserModifier: "command+shift",
            showsDockIcon: false,
            showsStatusItem: true,
            browserOptions: [
                BrowserOption(
                    id: "arc-default",
                    name: "Arc",
                    bundleIdentifier: "company.thebrowser.Browser",
                    appName: "Arc",
                    profileDirectory: nil,
                    extraArguments: nil
                ),
                BrowserOption(
                    id: "chrome-default",
                    name: "Chrome - Default",
                    bundleIdentifier: "com.google.Chrome",
                    appName: "Google Chrome",
                    profileDirectory: "Default",
                    extraArguments: nil
                ),
                BrowserOption(
                    id: "chrome-profile-1",
                    name: "Chrome - Profile 1",
                    bundleIdentifier: "com.google.Chrome",
                    appName: "Google Chrome",
                    profileDirectory: "Profile 1",
                    extraArguments: nil
                ),
                BrowserOption(
                    id: "edge-default",
                    name: "Edge - Default",
                    bundleIdentifier: "com.microsoft.edgemac",
                    appName: "Microsoft Edge",
                    profileDirectory: "Default",
                    extraArguments: nil
                ),
                BrowserOption(
                    id: "safari",
                    name: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    appName: "Safari",
                    profileDirectory: nil,
                    extraArguments: nil
                )
            ],
            routingRules: [
                RoutingRule(
                    id: "gmail",
                    name: "Gmail",
                    browserOptionID: "chrome-default",
                    hostContains: nil,
                    hostSuffix: "mail.google.com",
                    pathPrefix: nil,
                    urlContains: nil
                ),
                RoutingRule(
                    id: "outlook",
                    name: "Outlook",
                    browserOptionID: "edge-default",
                    hostContains: nil,
                    hostSuffix: "outlook.office.com",
                    pathPrefix: nil,
                    urlContains: nil
                ),
                RoutingRule(
                    id: "chatgpt",
                    name: "ChatGPT",
                    browserOptionID: "chrome-profile-1",
                    hostContains: nil,
                    hostSuffix: "chatgpt.com",
                    pathPrefix: nil,
                    urlContains: nil
                )
            ]
        )
    }
}
