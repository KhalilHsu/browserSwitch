import AppKit
import CoreServices
import CoreGraphics
import Foundation

struct BrowserOption: Codable, Hashable {
    var id: String
    var name: String
    var bundleIdentifier: String
    var appName: String?
    var profileDirectory: String?
    var extraArguments: [String]?
}

struct RoutingRule: Codable, Hashable {
    var id: String
    var name: String
    var browserOptionID: String
    var hostContains: String?
    var hostSuffix: String?
    var pathPrefix: String?
    var urlContains: String?
}

struct RouterConfiguration: Codable {
    var defaultOptionID: String
    var chooserModifier: String
    var browserOptions: [BrowserOption]
    var routingRules: [RoutingRule]

    enum CodingKeys: String, CodingKey {
        case defaultOptionID
        case chooserModifier
        case browserOptions
        case routingRules
    }

    init(
        defaultOptionID: String,
        chooserModifier: String,
        browserOptions: [BrowserOption],
        routingRules: [RoutingRule] = []
    ) {
        self.defaultOptionID = defaultOptionID
        self.chooserModifier = chooserModifier
        self.browserOptions = browserOptions
        self.routingRules = routingRules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultOptionID = try container.decode(String.self, forKey: .defaultOptionID)
        chooserModifier = try container.decodeIfPresent(String.self, forKey: .chooserModifier) ?? "command+shift"
        browserOptions = try container.decode([BrowserOption].self, forKey: .browserOptions)
        routingRules = try container.decodeIfPresent([RoutingRule].self, forKey: .routingRules) ?? []
    }

    static let supportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("BrowserRouter", isDirectory: true)
    }()

    static let configURL = supportDirectory.appendingPathComponent("config.json")

    static func load() -> RouterConfiguration {
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
            NSLog("BrowserRouter config load failed: \(error)")
            return .sample()
        }
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        try data.write(to: Self.configURL, options: .atomic)
    }

    static func sample() -> RouterConfiguration {
        RouterConfiguration(
            defaultOptionID: "arc-default",
            chooserModifier: "command+shift",
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
                browserOptions: mergedOptions,
                routingRules: configuration.routingRules
            ),
            removedUnavailableOptionNames: unavailableOptions.map(\.name),
            addedOptionNames: addedOptionNames,
            unresolvedRuleCount: unresolvedRuleCount
        )
    }
}

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
                    id: "\(spec.idPrefix)-\(slug(profile.directory))",
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
            return (directory: directory, displayName: name?.isEmpty == false ? name! : directory)
        }

        return profiles.sorted { $0.directory.localizedStandardCompare($1.directory) == .orderedAscending }
    }

    private static func slug(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}

enum ChooserModifier: String, CaseIterable {
    case commandShift = "command+shift"
    case optionShift = "option+shift"
    case controlShift = "control+shift"
    case commandOption = "command+option"
    case always = "always"

    var title: String {
        switch self {
        case .commandShift:
            return "Command + Shift"
        case .optionShift:
            return "Option + Shift"
        case .controlShift:
            return "Control + Shift"
        case .commandOption:
            return "Command + Option"
        case .always:
            return "Always show chooser"
        }
    }

    func matches(_ flags: CGEventFlags) -> Bool {
        switch self {
        case .commandShift:
            return flags.contains(.maskCommand) && flags.contains(.maskShift)
        case .optionShift:
            return flags.contains(.maskAlternate) && flags.contains(.maskShift)
        case .controlShift:
            return flags.contains(.maskControl) && flags.contains(.maskShift)
        case .commandOption:
            return flags.contains(.maskCommand) && flags.contains(.maskAlternate)
        case .always:
            return true
        }
    }
}

extension NSPopUpButton {
    func selectItem(withRepresentedObject representedObject: String) {
        for item in itemArray where item.representedObject as? String == representedObject {
            select(item)
            return
        }
    }
}

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

enum DefaultBrowserError: LocalizedError {
    case missingBundleIdentifier
    case registrationFailed(OSStatus)
    case setFailed(scheme: String, status: OSStatus)
    case verificationFailed(http: String?, https: String?)

    var errorDescription: String? {
        switch self {
        case .missingBundleIdentifier:
            return "BrowserRouter is missing a bundle identifier."
        case .registrationFailed(let status):
            return "Launch Services registration failed with status \(status)."
        case .setFailed(let scheme, let status):
            return "Setting the default handler for \(scheme) failed with status \(status)."
        case .verificationFailed(let http, let https):
            return "Verification failed. Current handlers are http=\(http ?? "nil"), https=\(https ?? "nil")."
        }
    }
}

final class DefaultBrowserManager {
    private let bundleURL: URL
    private let bundleIdentifier: String

    init(bundle: Bundle = .main) throws {
        guard let bundleIdentifier = bundle.bundleIdentifier else {
            throw DefaultBrowserError.missingBundleIdentifier
        }

        self.bundleIdentifier = bundleIdentifier
        self.bundleURL = bundle.bundleURL
    }

    @MainActor
    func setAsDefaultBrowser() async throws {
        let registerStatus = LSRegisterURL(bundleURL as CFURL, true)
        guard registerStatus == noErr else {
            throw DefaultBrowserError.registrationFailed(registerStatus)
        }

        for scheme in ["http", "https"] {
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpenURLsWithScheme: scheme)
            } catch {
                // Treat the actual Launch Services state as the source of truth.
                let current = currentHandler(for: scheme)
                guard current == bundleIdentifier else {
                    let nsError = error as NSError
                    let status = nsError.userInfo[NSUnderlyingErrorKey]
                        .flatMap { ($0 as? NSError)?.code }
                        ?? nsError.code
                    throw DefaultBrowserError.setFailed(scheme: scheme, status: OSStatus(status))
                }
            }
        }

        let httpHandler = currentHandler(for: "http")
        let httpsHandler = currentHandler(for: "https")
        guard httpHandler == bundleIdentifier, httpsHandler == bundleIdentifier else {
            throw DefaultBrowserError.verificationFailed(http: httpHandler, https: httpsHandler)
        }
    }

    func statusSummary() -> String {
        let http = currentHandler(for: "http") ?? "unset"
        let https = currentHandler(for: "https") ?? "unset"
        return "http -> \(http)\nhttps -> \(https)"
    }

    func isInstalledInApplications() -> Bool {
        bundleURL.path.hasPrefix("/Applications/")
    }

    private func currentHandler(for scheme: String) -> String? {
        guard let url = URL(string: "\(scheme)://example.com") else {
            return nil
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            return nil
        }

        return Bundle(url: appURL)?.bundleIdentifier
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    private let defaultBrowserPopup = NSPopUpButton()
    private let modifierPopup = NSPopUpButton()
    private let rulesTableView = NSTableView()
    private let ruleNameField = NSTextField()
    private let ruleHostSuffixField = NSTextField()
    private let ruleBrowserPopup = NSPopUpButton()
    private let autosaveStatusLabel = NSTextField(labelWithString: "Changes save automatically")
    private let browserSummaryLabel = NSTextField(labelWithString: "")
    private let ruleSummaryLabel = NSTextField(labelWithString: "")
    private var configuration: RouterConfiguration
    private var visibleBrowserOptions: [BrowserOption] = []
    private var isPopulatingRuleForm = false
    private let onSave: (RouterConfiguration) -> Void

    init(configuration: RouterConfiguration, onSave: @escaping (RouterConfiguration) -> Void) {
        self.configuration = configuration
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "BrowserRouter"
        window.isReleasedWhenClosed = false
        window.center()
        window.minSize = NSSize(width: 720, height: 600)

        super.init(window: window)
        window.delegate = self
        buildUI()
        reloadControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        guard let contentView = window?.contentView else {
            return
        }

        let title = NSTextField(labelWithString: "BrowserRouter")
        title.font = .boldSystemFont(ofSize: 22)
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(labelWithString: "Route external links to the browser or profile that fits the moment.")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.maximumNumberOfLines = 2
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let defaultLabel = NSTextField(labelWithString: "Default browser/profile")
        defaultLabel.translatesAutoresizingMaskIntoConstraints = false
        defaultBrowserPopup.translatesAutoresizingMaskIntoConstraints = false
        defaultBrowserPopup.target = self
        defaultBrowserPopup.action = #selector(defaultBrowserChanged)

        let modifierLabel = NSTextField(labelWithString: "Show chooser when")
        modifierLabel.translatesAutoresizingMaskIntoConstraints = false
        modifierPopup.translatesAutoresizingMaskIntoConstraints = false
        modifierPopup.target = self
        modifierPopup.action = #selector(modifierChanged)

        let detectButton = makeButton("Detect Profiles", action: #selector(detectProfiles))
        let refreshButton = makeButton("Refresh Browsers", action: #selector(refreshBrowsers))
        let revealButton = makeButton("Reveal Config", action: #selector(revealConfigFile))
        let closeButton = makeButton("Done", action: #selector(closeWindow))
        closeButton.keyEquivalent = "\r"

        autosaveStatusLabel.textColor = .secondaryLabelColor
        autosaveStatusLabel.font = .systemFont(ofSize: 12)
        autosaveStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        browserSummaryLabel.textColor = .secondaryLabelColor
        browserSummaryLabel.font = .systemFont(ofSize: 12)
        browserSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        ruleSummaryLabel.textColor = .secondaryLabelColor
        ruleSummaryLabel.font = .systemFont(ofSize: 12)
        ruleSummaryLabel.translatesAutoresizingMaskIntoConstraints = false

        let buttonStack = NSStackView(views: [refreshButton, detectButton, revealButton, closeButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .centerY
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        rulesTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")))
        rulesTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("match")))
        rulesTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("browser")))
        rulesTableView.tableColumns[0].title = "Rule"
        rulesTableView.tableColumns[0].width = 160
        rulesTableView.tableColumns[1].title = "Host Suffix"
        rulesTableView.tableColumns[1].width = 240
        rulesTableView.tableColumns[2].title = "Browser/Profile"
        rulesTableView.tableColumns[2].width = 260
        rulesTableView.delegate = self
        rulesTableView.dataSource = self
        rulesTableView.usesAlternatingRowBackgroundColors = true
        rulesTableView.allowsMultipleSelection = false
        rulesTableView.rowHeight = 28
        rulesTableView.intercellSpacing = NSSize(width: 8, height: 4)
        rulesTableView.action = #selector(selectRule)
        rulesTableView.target = self

        let rulesScrollView = NSScrollView()
        rulesScrollView.hasVerticalScroller = true
        rulesScrollView.documentView = rulesTableView
        rulesScrollView.translatesAutoresizingMaskIntoConstraints = false

        let rulesTitle = NSTextField(labelWithString: "Routing Rules")
        rulesTitle.font = .boldSystemFont(ofSize: 15)
        rulesTitle.translatesAutoresizingMaskIntoConstraints = false

        ruleNameField.placeholderString = "Rule name"
        ruleNameField.translatesAutoresizingMaskIntoConstraints = false
        ruleNameField.delegate = self
        ruleHostSuffixField.placeholderString = "Host suffix, e.g. chatgpt.com"
        ruleHostSuffixField.translatesAutoresizingMaskIntoConstraints = false
        ruleHostSuffixField.delegate = self
        ruleBrowserPopup.translatesAutoresizingMaskIntoConstraints = false
        ruleBrowserPopup.target = self
        ruleBrowserPopup.action = #selector(ruleBrowserChanged)

        let addRuleButton = makeButton("Add Rule", action: #selector(addRule))
        let updateRuleButton = makeButton("Update Selected", action: #selector(updateSelectedRule))
        let removeRuleButton = makeButton("Remove Selected", action: #selector(removeSelectedRule))
        addRuleButton.keyEquivalent = "\r"
        let ruleButtonStack = NSStackView(views: [addRuleButton, updateRuleButton, removeRuleButton])
        ruleButtonStack.orientation = .horizontal
        ruleButtonStack.spacing = 8
        ruleButtonStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(title)
        contentView.addSubview(subtitle)
        contentView.addSubview(defaultLabel)
        contentView.addSubview(defaultBrowserPopup)
        contentView.addSubview(modifierLabel)
        contentView.addSubview(modifierPopup)
        contentView.addSubview(browserSummaryLabel)
        contentView.addSubview(rulesTitle)
        contentView.addSubview(ruleSummaryLabel)
        contentView.addSubview(rulesScrollView)
        contentView.addSubview(ruleNameField)
        contentView.addSubview(ruleHostSuffixField)
        contentView.addSubview(ruleBrowserPopup)
        contentView.addSubview(ruleButtonStack)
        contentView.addSubview(autosaveStatusLabel)
        contentView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            title.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            subtitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            subtitle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            defaultLabel.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 18),
            defaultLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            defaultLabel.widthAnchor.constraint(equalToConstant: 160),
            defaultBrowserPopup.centerYAnchor.constraint(equalTo: defaultLabel.centerYAnchor),
            defaultBrowserPopup.leadingAnchor.constraint(equalTo: defaultLabel.trailingAnchor, constant: 12),
            defaultBrowserPopup.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            modifierLabel.topAnchor.constraint(equalTo: defaultLabel.bottomAnchor, constant: 14),
            modifierLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            modifierLabel.widthAnchor.constraint(equalTo: defaultLabel.widthAnchor),
            modifierPopup.centerYAnchor.constraint(equalTo: modifierLabel.centerYAnchor),
            modifierPopup.leadingAnchor.constraint(equalTo: modifierLabel.trailingAnchor, constant: 12),
            modifierPopup.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            browserSummaryLabel.topAnchor.constraint(equalTo: modifierPopup.bottomAnchor, constant: 8),
            browserSummaryLabel.leadingAnchor.constraint(equalTo: defaultBrowserPopup.leadingAnchor),
            browserSummaryLabel.trailingAnchor.constraint(equalTo: defaultBrowserPopup.trailingAnchor),

            rulesTitle.topAnchor.constraint(equalTo: browserSummaryLabel.bottomAnchor, constant: 20),
            rulesTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),

            ruleSummaryLabel.centerYAnchor.constraint(equalTo: rulesTitle.centerYAnchor),
            ruleSummaryLabel.leadingAnchor.constraint(equalTo: rulesTitle.trailingAnchor, constant: 10),
            ruleSummaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -18),

            rulesScrollView.topAnchor.constraint(equalTo: rulesTitle.bottomAnchor, constant: 10),
            rulesScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            rulesScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            rulesScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240),

            ruleNameField.topAnchor.constraint(equalTo: rulesScrollView.bottomAnchor, constant: 12),
            ruleNameField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            ruleNameField.widthAnchor.constraint(equalToConstant: 170),

            ruleHostSuffixField.centerYAnchor.constraint(equalTo: ruleNameField.centerYAnchor),
            ruleHostSuffixField.leadingAnchor.constraint(equalTo: ruleNameField.trailingAnchor, constant: 8),
            ruleHostSuffixField.widthAnchor.constraint(equalToConstant: 250),

            ruleBrowserPopup.centerYAnchor.constraint(equalTo: ruleNameField.centerYAnchor),
            ruleBrowserPopup.leadingAnchor.constraint(equalTo: ruleHostSuffixField.trailingAnchor, constant: 8),
            ruleBrowserPopup.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            ruleButtonStack.topAnchor.constraint(equalTo: ruleNameField.bottomAnchor, constant: 10),
            ruleButtonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            ruleButtonStack.bottomAnchor.constraint(lessThanOrEqualTo: buttonStack.topAnchor, constant: -18),

            autosaveStatusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            autosaveStatusLabel.trailingAnchor.constraint(lessThanOrEqualTo: buttonStack.leadingAnchor, constant: -12),
            autosaveStatusLabel.centerYAnchor.constraint(equalTo: buttonStack.centerYAnchor),

            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])
    }

    private func makeButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    func reload(with configuration: RouterConfiguration) {
        self.configuration = configuration
        reloadControls()
    }

    private func reloadControls() {
        visibleBrowserOptions = BrowserAvailability.installedOptions(from: configuration.browserOptions)
        defaultBrowserPopup.removeAllItems()
        ruleBrowserPopup.removeAllItems()

        for option in visibleBrowserOptions {
            defaultBrowserPopup.addItem(withTitle: option.name)
            defaultBrowserPopup.lastItem?.representedObject = option.id
            ruleBrowserPopup.addItem(withTitle: option.name)
            ruleBrowserPopup.lastItem?.representedObject = option.id
        }

        let resolvedDefaultID = visibleBrowserOptions.contains(where: { $0.id == configuration.defaultOptionID })
            ? configuration.defaultOptionID
            : visibleBrowserOptions.first?.id
        if let resolvedDefaultID {
            configuration.defaultOptionID = resolvedDefaultID
            defaultBrowserPopup.selectItem(withRepresentedObject: resolvedDefaultID)
        }

        modifierPopup.removeAllItems()
        for modifier in ChooserModifier.allCases {
            modifierPopup.addItem(withTitle: modifier.title)
            modifierPopup.lastItem?.representedObject = modifier.rawValue
        }
        modifierPopup.selectItem(withRepresentedObject: configuration.chooserModifier)

        rulesTableView.reloadData()
        updateSummaryLabels()
        if !configuration.routingRules.isEmpty {
            rulesTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            populateRuleForm(from: configuration.routingRules[0])
        } else {
            clearRuleForm()
        }
    }

    @objc private func detectProfiles() {
        configuration = ChromiumProfileScanner.mergeDetectedOptions(into: configuration)
        reloadControls()
        _ = persistConfiguration(statusMessage: "Profiles detected and saved")
    }

    @objc private func refreshBrowsers() {
        let result = BrowserInventory.refreshConfiguration(configuration)
        configuration = result.configuration
        reloadControls()
        _ = persistConfiguration(statusMessage: result.statusMessage)
    }

    private func persistConfiguration(statusMessage: String = "Saved automatically") -> Bool {
        do {
            configuration.defaultOptionID = selectedRepresentedObject(defaultBrowserPopup)
                ?? configuration.defaultOptionID
            configuration.chooserModifier = selectedRepresentedObject(modifierPopup)
                ?? ChooserModifier.commandShift.rawValue
            try configuration.save()
            onSave(configuration)
            autosaveStatusLabel.stringValue = statusMessage
            autosaveStatusLabel.textColor = .secondaryLabelColor
            return true
        } catch {
            autosaveStatusLabel.stringValue = "Autosave failed"
            autosaveStatusLabel.textColor = .systemRed
            showMessage("Could Not Save", "\(error)")
            return false
        }
    }

    private func updateSummaryLabels() {
        let unavailableCount = configuration.browserOptions.count - visibleBrowserOptions.count
        let browserText = unavailableCount == 0
            ? "\(visibleBrowserOptions.count) browser/profile option(s) available"
            : "\(visibleBrowserOptions.count) available, \(unavailableCount) unavailable"
        browserSummaryLabel.stringValue = browserText

        let unresolvedRuleCount = configuration.routingRules.filter { rule in
            !visibleBrowserOptions.contains(where: { $0.id == rule.browserOptionID })
        }.count
        ruleSummaryLabel.stringValue = unresolvedRuleCount == 0
            ? "\(configuration.routingRules.count) rule(s)"
            : "\(configuration.routingRules.count) rule(s), \(unresolvedRuleCount) need attention"
        ruleSummaryLabel.textColor = unresolvedRuleCount == 0 ? .secondaryLabelColor : .systemOrange
    }

    @objc private func revealConfigFile() {
        _ = RouterConfiguration.load()
        NSWorkspace.shared.activateFileViewerSelecting([RouterConfiguration.configURL])
    }

    @objc private func closeWindow() {
        window?.close()
    }

    @objc private func defaultBrowserChanged() {
        _ = persistConfiguration(statusMessage: "Default browser saved")
    }

    @objc private func modifierChanged() {
        _ = persistConfiguration(statusMessage: "Chooser modifier saved")
    }

    @objc private func ruleBrowserChanged() {
        _ = autosaveSelectedRuleIfPossible(statusMessage: "Selected rule updated automatically")
    }

    private func showMessage(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        guard let window else {
            alert.runModal()
            return
        }

        alert.beginSheetModal(for: window) { _ in }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        configuration.routingRules.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < configuration.routingRules.count else {
            return nil
        }

        let rule = configuration.routingRules[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""
        let text: String

        switch identifier {
        case "name":
            text = rule.name
        case "match":
            text = rule.hostSuffix ?? rule.hostContains ?? rule.pathPrefix ?? rule.urlContains ?? ""
        case "browser":
            if let option = configuration.browserOptions.first(where: { $0.id == rule.browserOptionID }) {
                text = BrowserAvailability.isInstalled(option) ? option.name : "\(option.name) (Unavailable)"
            } else {
                text = rule.browserOptionID
            }
        default:
            text = ""
        }

        let cell = NSTextField(labelWithString: text)
        cell.lineBreakMode = .byTruncatingTail
        return cell
    }

    @objc private func selectRule() {
        let row = rulesTableView.selectedRow
        guard row >= 0, row < configuration.routingRules.count else {
            clearRuleForm()
            return
        }

        populateRuleForm(from: configuration.routingRules[row])
    }

    @objc private func addRule() {
        let hostSuffix = ruleHostSuffixField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hostSuffix.isEmpty, let browserID = selectedRepresentedObject(ruleBrowserPopup) else {
            showMessage("Missing Rule Info", "Add a host suffix and choose a browser/profile.")
            return
        }

        let name = ruleNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let rule = RoutingRule(
            id: uniqueRuleID(from: name.isEmpty ? hostSuffix : name),
            name: name.isEmpty ? hostSuffix : name,
            browserOptionID: browserID,
            hostContains: nil,
            hostSuffix: hostSuffix,
            pathPrefix: nil,
            urlContains: nil
        )

        configuration.routingRules.append(rule)
        rulesTableView.reloadData()
        updateSummaryLabels()
        rulesTableView.selectRowIndexes(IndexSet(integer: configuration.routingRules.count - 1), byExtendingSelection: false)
        _ = persistConfiguration(statusMessage: "Rule added and saved")
    }

    @objc private func updateSelectedRule() {
        let row = rulesTableView.selectedRow
        guard row >= 0, row < configuration.routingRules.count else {
            showMessage("No Rule Selected", "Select a rule first.")
            return
        }

        let hostSuffix = ruleHostSuffixField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hostSuffix.isEmpty, let browserID = selectedRepresentedObject(ruleBrowserPopup) else {
            showMessage("Missing Rule Info", "Add a host suffix and choose a browser/profile.")
            return
        }

        let name = ruleNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        configuration.routingRules[row].name = name.isEmpty ? hostSuffix : name
        configuration.routingRules[row].browserOptionID = browserID
        configuration.routingRules[row].hostSuffix = hostSuffix
        configuration.routingRules[row].hostContains = nil
        configuration.routingRules[row].pathPrefix = nil
        configuration.routingRules[row].urlContains = nil
        rulesTableView.reloadData()
        updateSummaryLabels()
        rulesTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        _ = persistConfiguration(statusMessage: "Rule updated and saved")
    }

    @objc private func removeSelectedRule() {
        let row = rulesTableView.selectedRow
        guard row >= 0, row < configuration.routingRules.count else {
            showMessage("No Rule Selected", "Select a rule first.")
            return
        }

        configuration.routingRules.remove(at: row)
        rulesTableView.reloadData()
        updateSummaryLabels()
        clearRuleForm()
        _ = persistConfiguration(statusMessage: "Rule removed and saved")
    }

    private func populateRuleForm(from rule: RoutingRule) {
        isPopulatingRuleForm = true
        ruleNameField.stringValue = rule.name
        ruleHostSuffixField.stringValue = rule.hostSuffix ?? rule.hostContains ?? rule.pathPrefix ?? rule.urlContains ?? ""
        ruleBrowserPopup.selectItem(withRepresentedObject: rule.browserOptionID)
        isPopulatingRuleForm = false
    }

    private func clearRuleForm() {
        isPopulatingRuleForm = true
        ruleNameField.stringValue = ""
        ruleHostSuffixField.stringValue = ""
        if !visibleBrowserOptions.isEmpty {
            ruleBrowserPopup.selectItem(at: 0)
        }
        isPopulatingRuleForm = false
    }

    private func selectedRepresentedObject(_ popup: NSPopUpButton) -> String? {
        popup.selectedItem?.representedObject as? String
    }

    private func uniqueRuleID(from value: String) -> String {
        let base = value
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." }
        var candidate = base.isEmpty ? "rule" : base
        var suffix = 2

        while configuration.routingRules.contains(where: { $0.id == candidate }) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }

        return candidate
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard !isPopulatingRuleForm else {
            return
        }

        _ = autosaveSelectedRuleIfPossible(statusMessage: "Selected rule updated automatically")
    }

    func windowWillClose(_ notification: Notification) {
        _ = autosaveSelectedRuleIfPossible(statusMessage: "Selected rule updated automatically")
    }

    private func autosaveSelectedRuleIfPossible(statusMessage: String) -> Bool {
        guard !isPopulatingRuleForm else {
            return false
        }

        let row = rulesTableView.selectedRow
        guard row >= 0, row < configuration.routingRules.count else {
            return false
        }

        let hostSuffix = ruleHostSuffixField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hostSuffix.isEmpty, let browserID = selectedRepresentedObject(ruleBrowserPopup) else {
            return false
        }

        let name = ruleNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedName = name.isEmpty ? hostSuffix : name

        let currentRule = configuration.routingRules[row]
        guard
            currentRule.name != updatedName
                || currentRule.browserOptionID != browserID
                || currentRule.hostSuffix != hostSuffix
                || currentRule.hostContains != nil
                || currentRule.pathPrefix != nil
                || currentRule.urlContains != nil
        else {
            return false
        }

        configuration.routingRules[row].name = updatedName
        configuration.routingRules[row].browserOptionID = browserID
        configuration.routingRules[row].hostSuffix = hostSuffix
        configuration.routingRules[row].hostContains = nil
        configuration.routingRules[row].pathPrefix = nil
        configuration.routingRules[row].urlContains = nil
        rulesTableView.reloadData()
        updateSummaryLabels()
        rulesTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        return persistConfiguration(statusMessage: statusMessage)
    }
}

@MainActor
final class BrowserChooserWindowController: NSWindowController, NSWindowDelegate {
    private let url: URL
    private let options: [BrowserOption]
    private let defaultOptionID: String
    private let onSelect: (BrowserOption) -> Void
    private let onClose: () -> Void

    init(
        url: URL,
        options: [BrowserOption],
        defaultOptionID: String,
        onSelect: @escaping (BrowserOption) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.url = url
        self.options = options
        self.defaultOptionID = defaultOptionID
        self.onSelect = onSelect
        self.onClose = onClose

        let windowHeight = min(640, max(320, CGFloat(options.count) * 44 + 140))
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: windowHeight),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Open Link"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        guard let contentView = window?.contentView else {
            return
        }

        let title = NSTextField(labelWithString: "Open this link with")
        title.font = .boldSystemFont(ofSize: 18)
        title.translatesAutoresizingMaskIntoConstraints = false

        let detail = NSTextField(labelWithString: displayURL)
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingMiddle
        detail.maximumNumberOfLines = 1
        detail.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (index, option) in options.enumerated() {
            let button = NSButton(title: buttonTitle(for: option, index: index), target: self, action: #selector(selectOption(_:)))
            button.bezelStyle = .rounded
            button.alignment = .left
            button.tag = index
            if index < 9 {
                button.keyEquivalent = "\(index + 1)"
            }
            stack.addArrangedSubview(button)
        }

        let hint = NSTextField(labelWithString: "Use number keys for the first nine choices. Press Esc to cancel.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(title)
        contentView.addSubview(detail)
        contentView.addSubview(stack)
        contentView.addSubview(hint)
        contentView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: title.trailingAnchor),

            stack.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: title.trailingAnchor),

            hint.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 14),
            hint.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            hint.trailingAnchor.constraint(lessThanOrEqualTo: cancelButton.leadingAnchor, constant: -12),
            hint.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            cancelButton.centerYAnchor.constraint(equalTo: hint.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: title.trailingAnchor)
        ])
    }

    private var displayURL: String {
        if let host = url.host, !host.isEmpty {
            return host + url.path
        }

        return url.absoluteString
    }

    private func buttonTitle(for option: BrowserOption, index: Int) -> String {
        let shortcut = index < 9 ? "\(index + 1). " : ""
        let defaultMarker = option.id == defaultOptionID ? "  Default" : ""
        return "\(shortcut)\(option.name)\(defaultMarker)"
    }

    func showNearMouse() {
        guard let window else {
            return
        }

        let mouse = NSEvent.mouseLocation
        let frame = window.frame
        window.setFrameOrigin(NSPoint(x: mouse.x - frame.width / 2, y: mouse.y - 24))
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func selectOption(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < options.count else {
            return
        }

        let option = options[sender.tag]
        close()
        onSelect(option)
    }

    @objc private func cancel() {
        close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

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
        for rule in configuration.routingRules where matches(rule, url: url) {
            guard let option = configuration.browserOptions.first(where: { $0.id == rule.browserOptionID }) else {
                continue
            }

            if launcher.isInstalled(option) {
                return option
            }
        }

        return nil
    }

    private func matches(_ rule: RoutingRule, url: URL) -> Bool {
        let absolute = url.absoluteString.lowercased()
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()

        if let urlContains = rule.urlContains?.lowercased(), !absolute.contains(urlContains) {
            return false
        }

        if let hostContains = rule.hostContains?.lowercased(), !host.contains(hostContains) {
            return false
        }

        if let hostSuffix = rule.hostSuffix?.lowercased() {
            let normalized = hostSuffix.hasPrefix(".") ? String(hostSuffix.dropFirst()) : hostSuffix
            guard host == normalized || host.hasSuffix(".\(normalized)") else {
                return false
            }
        }

        if let pathPrefix = rule.pathPrefix?.lowercased(), !path.hasPrefix(pathPrefix) {
            return false
        }

        return rule.urlContains != nil
            || rule.hostContains != nil
            || rule.hostSuffix != nil
            || rule.pathPrefix != nil
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

@main
struct BrowserRouterApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
