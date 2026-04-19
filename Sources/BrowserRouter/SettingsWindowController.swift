import AppKit
import Foundation
import BrowserRouterCore

private enum RuleMatchField: String, CaseIterable {
    case hostSuffix
    case hostContains
    case pathPrefix
    case urlContains

    var title: String {
        switch self {
        case .hostSuffix:
            return "Host Suffix"
        case .hostContains:
            return "Host Contains"
        case .pathPrefix:
            return "Path Prefix"
        case .urlContains:
            return "URL Contains"
        }
    }

    var placeholder: String {
        switch self {
        case .hostSuffix:
            return "e.g. chatgpt.com"
        case .hostContains:
            return "e.g. google"
        case .pathPrefix:
            return "e.g. /work"
        case .urlContains:
            return "e.g. token"
        }
    }

    func value(from rule: RoutingRule) -> String? {
        switch self {
        case .hostSuffix:
            return rule.hostSuffix
        case .hostContains:
            return rule.hostContains
        case .pathPrefix:
            return rule.pathPrefix
        case .urlContains:
            return rule.urlContains
        }
    }

    func apply(_ value: String, to rule: inout RoutingRule) {
        rule.hostContains = nil
        rule.hostSuffix = nil
        rule.pathPrefix = nil
        rule.urlContains = nil

        switch self {
        case .hostSuffix:
            rule.hostSuffix = value
        case .hostContains:
            rule.hostContains = value
        case .pathPrefix:
            rule.pathPrefix = value
        case .urlContains:
            rule.urlContains = value
        }
    }

    static func preferredField(for rule: RoutingRule) -> RuleMatchField {
        allCases.first { field in
            guard let value = field.value(from: rule) else {
                return false
            }

            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? .hostSuffix
    }

    static func matchDescription(for rule: RoutingRule) -> String {
        allCases.compactMap { field in
            guard let value = field.value(from: rule), !value.isEmpty else {
                return nil
            }

            return "\(field.title): \(value)"
        }.joined(separator: ", ")
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    private let appearanceTitle = NSTextField(labelWithString: "Appearance")
    private let showDockIconCheckBox = NSButton(checkboxWithTitle: "Show Dock icon", target: nil, action: nil)
    private let showStatusItemCheckBox = NSButton(checkboxWithTitle: "Show menu bar icon", target: nil, action: nil)
    private let defaultBrowserPopup = NSPopUpButton()
    private let modifierPopup = NSPopUpButton()
    private let rulesTableView = NSTableView()
    private let ruleNameField = NSTextField()
    private let ruleMatchTypePopup = NSPopUpButton()
    private let ruleMatchValueField = NSTextField()
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

        appearanceTitle.font = .boldSystemFont(ofSize: 15)
        appearanceTitle.translatesAutoresizingMaskIntoConstraints = false
        showDockIconCheckBox.target = self
        showDockIconCheckBox.action = #selector(presentationChanged)
        showDockIconCheckBox.translatesAutoresizingMaskIntoConstraints = false
        showStatusItemCheckBox.target = self
        showStatusItemCheckBox.action = #selector(presentationChanged)
        showStatusItemCheckBox.translatesAutoresizingMaskIntoConstraints = false

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
        rulesTableView.tableColumns[1].title = "Match"
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
        ruleMatchTypePopup.translatesAutoresizingMaskIntoConstraints = false
        ruleMatchTypePopup.target = self
        ruleMatchTypePopup.action = #selector(ruleMatchTypeChanged)
        for field in RuleMatchField.allCases {
            ruleMatchTypePopup.addItem(withTitle: field.title)
            ruleMatchTypePopup.lastItem?.representedObject = field.rawValue
        }
        ruleMatchValueField.placeholderString = RuleMatchField.hostSuffix.placeholder
        ruleMatchValueField.translatesAutoresizingMaskIntoConstraints = false
        ruleMatchValueField.delegate = self
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
        contentView.addSubview(appearanceTitle)
        contentView.addSubview(showDockIconCheckBox)
        contentView.addSubview(showStatusItemCheckBox)
        contentView.addSubview(defaultLabel)
        contentView.addSubview(defaultBrowserPopup)
        contentView.addSubview(modifierLabel)
        contentView.addSubview(modifierPopup)
        contentView.addSubview(browserSummaryLabel)
        contentView.addSubview(rulesTitle)
        contentView.addSubview(ruleSummaryLabel)
        contentView.addSubview(rulesScrollView)
        contentView.addSubview(ruleNameField)
        contentView.addSubview(ruleMatchTypePopup)
        contentView.addSubview(ruleMatchValueField)
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

            appearanceTitle.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 18),
            appearanceTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            appearanceTitle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            showDockIconCheckBox.topAnchor.constraint(equalTo: appearanceTitle.bottomAnchor, constant: 10),
            showDockIconCheckBox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),

            showStatusItemCheckBox.centerYAnchor.constraint(equalTo: showDockIconCheckBox.centerYAnchor),
            showStatusItemCheckBox.leadingAnchor.constraint(equalTo: showDockIconCheckBox.trailingAnchor, constant: 24),

            defaultLabel.topAnchor.constraint(equalTo: showDockIconCheckBox.bottomAnchor, constant: 18),
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

            ruleMatchTypePopup.centerYAnchor.constraint(equalTo: ruleNameField.centerYAnchor),
            ruleMatchTypePopup.leadingAnchor.constraint(equalTo: ruleNameField.trailingAnchor, constant: 8),
            ruleMatchTypePopup.widthAnchor.constraint(equalToConstant: 140),

            ruleMatchValueField.centerYAnchor.constraint(equalTo: ruleNameField.centerYAnchor),
            ruleMatchValueField.leadingAnchor.constraint(equalTo: ruleMatchTypePopup.trailingAnchor, constant: 8),
            ruleMatchValueField.widthAnchor.constraint(equalToConstant: 220),

            ruleBrowserPopup.centerYAnchor.constraint(equalTo: ruleNameField.centerYAnchor),
            ruleBrowserPopup.leadingAnchor.constraint(equalTo: ruleMatchValueField.trailingAnchor, constant: 8),
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
        showDockIconCheckBox.state = configuration.showsDockIcon ? .on : .off
        showStatusItemCheckBox.state = configuration.showsStatusItem ? .on : .off
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
            configuration.showsDockIcon = showDockIconCheckBox.state == .on
            configuration.showsStatusItem = showStatusItemCheckBox.state == .on
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

    @objc private func presentationChanged() {
        _ = persistConfiguration(statusMessage: "Appearance saved")
    }

    @objc private func ruleBrowserChanged() {
        _ = autosaveSelectedRuleIfPossible(statusMessage: "Selected rule updated automatically")
    }

    @objc private func ruleMatchTypeChanged() {
        updateRuleMatchPlaceholder()
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
            text = RuleMatchField.matchDescription(for: rule)
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
        guard let draft = ruleDraftFromForm() else {
            showMessage("Missing Rule Info", "Choose a match type, add a match value, and choose a browser/profile.")
            return
        }

        let name = ruleNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var rule = RoutingRule(
            id: uniqueRuleID(from: name.isEmpty ? draft.matchValue : name),
            name: name.isEmpty ? draft.matchValue : name,
            browserOptionID: draft.browserID,
            hostContains: nil,
            hostSuffix: nil,
            pathPrefix: nil,
            urlContains: nil
        )
        draft.matchField.apply(draft.matchValue, to: &rule)

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

        guard let draft = ruleDraftFromForm() else {
            showMessage("Missing Rule Info", "Choose a match type, add a match value, and choose a browser/profile.")
            return
        }

        let name = ruleNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        configuration.routingRules[row].name = name.isEmpty ? draft.matchValue : name
        configuration.routingRules[row].browserOptionID = draft.browserID
        draft.matchField.apply(draft.matchValue, to: &configuration.routingRules[row])
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
        let matchField = RuleMatchField.preferredField(for: rule)
        ruleMatchTypePopup.selectItem(withRepresentedObject: matchField.rawValue)
        ruleMatchValueField.stringValue = matchField.value(from: rule) ?? ""
        updateRuleMatchPlaceholder()
        ruleBrowserPopup.selectItem(withRepresentedObject: rule.browserOptionID)
        isPopulatingRuleForm = false
    }

    private func clearRuleForm() {
        isPopulatingRuleForm = true
        ruleNameField.stringValue = ""
        ruleMatchTypePopup.selectItem(withRepresentedObject: RuleMatchField.hostSuffix.rawValue)
        ruleMatchValueField.stringValue = ""
        updateRuleMatchPlaceholder()
        if !visibleBrowserOptions.isEmpty {
            ruleBrowserPopup.selectItem(at: 0)
        }
        isPopulatingRuleForm = false
    }

    private func selectedRepresentedObject(_ popup: NSPopUpButton) -> String? {
        popup.selectedItem?.representedObject as? String
    }

    private func selectedRuleMatchField() -> RuleMatchField? {
        selectedRepresentedObject(ruleMatchTypePopup).flatMap(RuleMatchField.init(rawValue:))
    }

    private func ruleDraftFromForm() -> (matchField: RuleMatchField, matchValue: String, browserID: String)? {
        let matchValue = ruleMatchValueField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !matchValue.isEmpty,
            let matchField = selectedRuleMatchField(),
            let browserID = selectedRepresentedObject(ruleBrowserPopup)
        else {
            return nil
        }

        return (matchField, matchValue, browserID)
    }

    private func updateRuleMatchPlaceholder() {
        ruleMatchValueField.placeholderString = selectedRuleMatchField()?.placeholder ?? RuleMatchField.hostSuffix.placeholder
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

        guard let draft = ruleDraftFromForm() else {
            return false
        }

        let name = ruleNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedName = name.isEmpty ? draft.matchValue : name

        let currentRule = configuration.routingRules[row]
        var updatedRule = currentRule
        updatedRule.name = updatedName
        updatedRule.browserOptionID = draft.browserID
        draft.matchField.apply(draft.matchValue, to: &updatedRule)

        guard currentRule != updatedRule else {
            return false
        }

        configuration.routingRules[row] = updatedRule
        rulesTableView.reloadData()
        updateSummaryLabels()
        rulesTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        return persistConfiguration(statusMessage: statusMessage)
    }
}
