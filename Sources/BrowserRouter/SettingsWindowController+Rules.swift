import AppKit
import BrowserRouterCore

extension SettingsWindowController {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === rulesTableView {
            return configuration.routingRules.count
        } else if tableView === browsersTableView {
            return configuration.browserOptions.count
        }
        return 0
    }

    /// Wraps a subview in a container that vertically (and optionally horizontally) centers it within the table cell.
    private func centeredCellView(_ subview: NSView, centerHorizontally: Bool = false) -> NSView {
        subview.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(subview)
        var constraints = [
            subview.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            subview.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor, constant: 2),
            subview.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -2)
        ]
        if centerHorizontally {
            constraints.append(subview.centerXAnchor.constraint(equalTo: container.centerXAnchor))
        } else {
            constraints.append(subview.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2))
            constraints.append(subview.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -2))
        }
        NSLayoutConstraint.activate(constraints)
        return container
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === browsersTableView {
            guard row < configuration.browserOptions.count else {
                return nil
            }

            let option = configuration.browserOptions[row]
            let identifier = tableColumn?.identifier.rawValue ?? ""

            if identifier == "visible" {
                let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleBrowserVisibility(_:)))
                checkbox.state = option.isHidden ? .off : .on
                checkbox.tag = row
                return centeredCellView(checkbox, centerHorizontally: true)
            }

            if identifier == "name" {
                let cell = NSTextField(labelWithString: option.name)
                cell.lineBreakMode = .byTruncatingTail
                cell.maximumNumberOfLines = 1
                cell.textColor = option.isHidden ? .tertiaryLabelColor : .labelColor
                return centeredCellView(cell)
            }
            return nil
        }

        guard row < configuration.routingRules.count else {
            return nil
        }

        let rule = configuration.routingRules[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""

        if identifier == "order" {
            let cell = NSTextField(labelWithString: "\(row + 1)")
            cell.alignment = .center
            cell.textColor = rule.isEnabled ? .secondaryLabelColor : .tertiaryLabelColor
            cell.toolTip = L("Rules run from top to bottom. The first match wins.")
            return centeredCellView(cell, centerHorizontally: true)
        }

        if identifier == "enabled" {
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleRuleEnabled(_:)))
            checkbox.state = rule.isEnabled ? .on : .off
            checkbox.tag = row
            checkbox.toolTip = rule.isEnabled ? L("Rule is enabled") : L("Rule is disabled")
            return centeredCellView(checkbox, centerHorizontally: true)
        }

        let text: String

        switch identifier {
        case "name":
            text = rule.name
        case "match":
            let match = ruleConditionDescription(for: rule)
            text = match.isEmpty ? L("Any URL") : match
        case "browser":
            if let option = configuration.browserOptions.first(where: { $0.id == rule.browserOptionID }) {
                text = BrowserAvailability.isInstalled(option) ? option.name : L("%@ (Unavailable)", option.name)
            } else {
                text = rule.browserOptionID
            }
        default:
            text = ""
        }

        let cell = NSTextField(labelWithString: text)
        cell.lineBreakMode = .byTruncatingTail
        cell.maximumNumberOfLines = 1
        cell.textColor = rule.isEnabled ? .labelColor : .tertiaryLabelColor
        cell.toolTip = text
        return centeredCellView(cell)
    }

    @objc func selectRule() {
        updateRuleEditorState()
        updateRuleTesterResult()
    }

    @objc func editClickedRule() {
        let row = rulesTableView.clickedRow
        guard row >= 0, row < configuration.routingRules.count else {
            return
        }

        presentRuleEditor(editing: row)
    }

    @objc func editSelectedRule() {
        let row = rulesTableView.selectedRow
        guard row >= 0, row < configuration.routingRules.count else {
            return
        }

        presentRuleEditor(editing: row)
    }

    @objc func toggleRuleEnabled(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < configuration.routingRules.count else {
            return
        }

        configuration.routingRules[row].isEnabled = sender.state == .on
        rulesTableView.reloadData()
        updateSummaryLabels()
        updateRuleTesterResult()
        rulesTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        _ = persistConfiguration(statusMessage: configuration.routingRules[row].isEnabled ? L("Rule enabled") : L("Rule disabled"))
        updateRuleEditorState()
    }

    @objc func startNewRule() {
        presentRuleEditor(editing: nil)
    }

    func addRule(from draft: (matchField: RuleMatchField, matchValue: String, browserID: String)) {
        let name = ruleDisplayName(for: draft)
        var rule = RoutingRule(
            id: uniqueRuleID(from: name),
            name: name,
            browserOptionID: draft.browserID,
            hostContains: nil,
            hostSuffix: nil,
            pathPrefix: nil,
            urlContains: nil,
            sourceAppBundleID: selectedSourceAppBundleID()
        )
        applyRuleDraft(draft, to: &rule)

        configuration.routingRules.append(rule)
        rulesTableView.reloadData()
        updateSummaryLabels()
        let newRow = configuration.routingRules.count - 1
        rulesTableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        rulesTableView.scrollRowToVisible(newRow)
        _ = persistConfiguration(statusMessage: L("Rule added and saved"))
        updateRuleEditorState()
        updateRuleTesterResult()
    }

    func updateRule(at row: Int, with draft: (matchField: RuleMatchField, matchValue: String, browserID: String)) {
        configuration.routingRules[row].name = ruleDisplayName(for: draft)
        configuration.routingRules[row].browserOptionID = draft.browserID
        configuration.routingRules[row].sourceAppBundleID = selectedSourceAppBundleID()
        applyRuleDraft(draft, to: &configuration.routingRules[row])
        rulesTableView.reloadData()
        updateSummaryLabels()
        rulesTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        _ = persistConfiguration(statusMessage: L("Rule updated and saved"))
        updateRuleEditorState()
        updateRuleTesterResult()
    }

    @objc func removeSelectedRule() {
        let row = rulesTableView.selectedRow
        guard row >= 0, row < configuration.routingRules.count, let window else {
            return
        }

        let alert = NSAlert()
        alert.messageText = L("Remove rule \"%@\"?", configuration.routingRules[row].name)
        alert.informativeText = L("This can't be undone.")
        alert.addButton(withTitle: L("Remove"))
        alert.addButton(withTitle: L("Cancel"))
        if #available(macOS 11.0, *) {
            alert.buttons.first?.hasDestructiveAction = true
        }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn,
                  row < self.configuration.routingRules.count
            else {
                return
            }

            self.configuration.routingRules.remove(at: row)
            self.rulesTableView.reloadData()
            self.updateSummaryLabels()
            _ = self.persistConfiguration(statusMessage: L("Rule removed and saved"))
            self.updateRuleEditorState()
            self.updateRuleTesterResult()
        }
    }

    @objc func moveSelectedRuleUp() {
        moveSelectedRule(by: -1)
    }

    @objc func moveSelectedRuleDown() {
        moveSelectedRule(by: 1)
    }

    func moveSelectedRule(by offset: Int) {
        let row = rulesTableView.selectedRow
        let destination = row + offset
        guard row >= 0,
              row < configuration.routingRules.count,
              destination >= 0,
              destination < configuration.routingRules.count
        else {
            return
        }

        configuration.routingRules.swapAt(row, destination)
        rulesTableView.reloadData()
        rulesTableView.selectRowIndexes(IndexSet(integer: destination), byExtendingSelection: false)
        updateSummaryLabels()
        _ = persistConfiguration(statusMessage: L("Rule priority updated"))
        updateRuleEditorState()
        updateRuleTesterResult()
    }

    func populateRuleForm(from rule: RoutingRule) {
        isPopulatingRuleForm = true
        ruleNameField.stringValue = rule.name
        let matchField = RuleMatchField.preferredField(for: rule)
        ruleMatchTypePopup.selectItem(withRepresentedObject: matchField.rawValue)
        ruleMatchValueField.stringValue = matchField.value(from: rule) ?? ""
        updateRuleMatchPlaceholder()
        ruleBrowserPopup.selectItem(withRepresentedObject: rule.browserOptionID)
        if let sourceApp = rule.sourceAppBundleID, !sourceApp.isEmpty {
            ruleSourceAppPopup.selectItem(withRepresentedObject: sourceApp)
        } else {
            ruleSourceAppPopup.selectItem(at: 0)
        }
        lastSourceAppSelection = selectedRepresentedObject(ruleSourceAppPopup) ?? ""
        isPopulatingRuleForm = false
    }

    func clearRuleForm() {
        isPopulatingRuleForm = true
        ruleNameField.stringValue = ""
        ruleMatchTypePopup.selectItem(withRepresentedObject: RuleMatchField.hostSuffix.rawValue)
        ruleMatchValueField.stringValue = ""
        updateRuleMatchPlaceholder()
        if !visibleBrowserOptions.isEmpty {
            ruleBrowserPopup.selectItem(at: 0)
        }
        ruleSourceAppPopup.selectItem(at: 0)
        lastSourceAppSelection = ""
        isPopulatingRuleForm = false
    }

    /// Enables the actions under the rules table that need a selected rule.
    func updateRuleEditorState() {
        let row = rulesTableView.selectedRow
        let hasSelection = row >= 0 && row < configuration.routingRules.count
        editRuleButton.isEnabled = hasSelection
        removeRuleButton.isEnabled = hasSelection
        moveRuleUpButton.isEnabled = hasSelection && row > 0
        moveRuleDownButton.isEnabled = hasSelection && row < configuration.routingRules.count - 1
    }

    func ruleConditionDescription(for rule: RoutingRule) -> String {
        var parts: [String] = []
        if let sourceApp = rule.sourceAppBundleID, !sourceApp.isEmpty {
            parts.append(L("From %@", displayNameForSourceApp(sourceApp)))
        }
        let match = RuleMatchField.matchDescription(for: rule)
        if !match.isEmpty {
            parts.append(match)
        }
        return parts.joined(separator: " + ")
    }

    func displayNameForSourceApp(_ bundleID: String) -> String {
        if let item = ruleSourceAppPopup.itemArray.first(where: { ($0.representedObject as? String) == bundleID }) {
            return item.title
        }
        return bundleID
    }

    func selectedRuleMatchField() -> RuleMatchField? {
        selectedRepresentedObject(ruleMatchTypePopup).flatMap(RuleMatchField.init(rawValue:))
    }

    func selectedSourceAppBundleID() -> String? {
        guard let value = selectedRepresentedObject(ruleSourceAppPopup), !value.isEmpty, value != chooseOtherSourceAppToken else {
            return nil
        }
        return value
    }

    func ruleDraftFromForm() -> (matchField: RuleMatchField, matchValue: String, browserID: String)? {
        let matchValue = ruleMatchValueField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSourceApp = selectedSourceAppBundleID() != nil
        guard
            !matchValue.isEmpty || hasSourceApp,
            let matchField = selectedRuleMatchField(),
            let browserID = selectedRepresentedObject(ruleBrowserPopup)
        else {
            return nil
        }

        return (matchField, matchValue, browserID)
    }

    func ruleDisplayName(for draft: (matchField: RuleMatchField, matchValue: String, browserID: String)) -> String {
        let name = ruleNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return name
        }
        if !draft.matchValue.isEmpty {
            return draft.matchValue
        }
        if let sourceApp = selectedSourceAppBundleID() {
            return L("From %@", displayNameForSourceApp(sourceApp))
        }
        return L("Draft Rule")
    }

    func updateRuleMatchPlaceholder() {
        ruleMatchValueField.placeholderString = selectedRuleMatchField()?.placeholder ?? RuleMatchField.hostSuffix.placeholder
    }

    func validateRuleDraft(_ draft: (matchField: RuleMatchField, matchValue: String, browserID: String), showsAlert: Bool) -> Bool {
        if !draft.matchValue.isEmpty, draft.matchField == .pathPrefix, !draft.matchValue.hasPrefix("/") {
            if showsAlert {
                showMessage(
                    L("Path Match Needs A Slash"),
                    L("Path Starts With matches the URL path after the domain. Use a value like /docs. To match baidu.com, choose Domain Suffix and enter baidu.com.")
                )
            }
            return false
        }

        return true
    }

    func applyRuleDraft(_ draft: (matchField: RuleMatchField, matchValue: String, browserID: String), to rule: inout RoutingRule) {
        rule.hostContains = nil
        rule.hostSuffix = nil
        rule.pathPrefix = nil
        rule.urlContains = nil
        if !draft.matchValue.isEmpty {
            draft.matchField.apply(draft.matchValue, to: &rule)
        }
    }

    func uniqueRuleID(from value: String) -> String {
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
        if let field = obj.object as? NSTextField, field === ruleTesterURLField {
            updateRuleTesterResult()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else {
            return
        }

        if field === ruleTesterURLField {
            updateRuleTesterResult()
        } else if field === ruleMatchValueField || field === ruleNameField {
            guard !isPopulatingRuleForm else {
                return
            }
            updateRuleEditorSheetState()
        }
    }

    func windowWillClose(_ notification: Notification) {}

    func updateRuleTesterResult() {
        guard !isUpdatingRuleTester else {
            return
        }

        isUpdatingRuleTester = true
        defer {
            isUpdatingRuleTester = false
        }

        let rawValue = ruleTesterURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty else {
            ruleTesterResultLabel.stringValue = L("Paste a URL to preview routing.")
            ruleTesterResultLabel.textColor = .secondaryLabelColor
            return
        }

        guard let url = normalizedRuleTesterURL(from: rawValue) else {
            ruleTesterResultLabel.stringValue = L("Enter a valid URL or domain, such as www.baidu.com.")
            ruleTesterResultLabel.textColor = .systemOrange
            return
        }

        let availableOptionIDs = Set(visibleBrowserOptions.map(\.id))
        let chooserModifier = ChooserModifier(rawValue: configuration.chooserModifier) ?? .commandShift
        let testerSourceApp: String? = nil
        let previewConfiguration = configuration
        let resolution = RouteResolver.resolve(
            url: url,
            configuration: previewConfiguration,
            availableOptionIDs: availableOptionIDs,
            chooserOverride: chooserModifier == .always,
            sourceApp: testerSourceApp
        )

        let chooserText = chooserModifier == .always
            ? L("Chooser override: always on.")
            : L("Chooser override: hold %@.", chooserModifier.title)
        let normalizedText = normalizedRuleTesterPrefix(rawValue: rawValue, url: url)
        let sourceAppText = testerSourceApp.map { L(" (Source: %@)", $0) } ?? ""

        switch resolution {
        case .chooserOverride:
            ruleTesterResultLabel.stringValue = L("%@%@ Routing rules will not run.", normalizedText, chooserText)
            ruleTesterResultLabel.textColor = .secondaryLabelColor
        case .matchedRule(let rule, let option):
            ruleTesterResultLabel.stringValue = L("%@Matched rule: %@. Target: %@. %@%@", normalizedText, rule.name, option.name, chooserText, sourceAppText)
            ruleTesterResultLabel.textColor = .secondaryLabelColor
        case .unavailableRule(let rule, let option):
            let targetName = option?.name ?? rule.browserOptionID
            ruleTesterResultLabel.stringValue = L("%@Matched rule: %@. Target unavailable: %@. BrowserRouter will use fallback/default routing.", normalizedText, rule.name, targetName)
            ruleTesterResultLabel.textColor = .systemOrange
        case .defaultRoute(let option):
            let diagnostic = ruleTesterDiagnostic(for: url, configuration: previewConfiguration)
            ruleTesterResultLabel.stringValue = diagnostic.map { normalizedText + $0 }
                ?? L("%@No enabled rule matched. Default target: %@. %@%@", normalizedText, option.name, chooserText, sourceAppText)
            ruleTesterResultLabel.textColor = diagnostic == nil ? .secondaryLabelColor : .systemOrange
        case .unavailableDefault(let option):
            let targetName = option?.name ?? configuration.defaultOptionID
            let diagnostic = ruleTesterDiagnostic(for: url, configuration: previewConfiguration)
            ruleTesterResultLabel.stringValue = diagnostic.map { normalizedText + $0 }
                ?? L("%@No enabled rule matched. Default target unavailable: %@. BrowserRouter will use another available browser.", normalizedText, targetName)
            ruleTesterResultLabel.textColor = .systemOrange
        case .fallback(let option):
            let diagnostic = ruleTesterDiagnostic(for: url, configuration: previewConfiguration)
            ruleTesterResultLabel.stringValue = diagnostic.map { normalizedText + $0 }
                ?? L("%@No enabled rule matched. Configured default is missing, so BrowserRouter will use %@.", normalizedText, option.name)
            ruleTesterResultLabel.textColor = .systemOrange
        case .noOptions:
            let diagnostic = ruleTesterDiagnostic(for: url, configuration: previewConfiguration)
            ruleTesterResultLabel.stringValue = diagnostic.map { normalizedText + $0 }
                ?? L("%@No enabled rule matched and no default browser/profile is configured.", normalizedText)
            ruleTesterResultLabel.textColor = .systemRed
        }
    }

    func normalizedRuleTesterPrefix(rawValue: String, url: URL) -> String {
        rawValue.contains("://") ? "" : L("Testing as %@. ", url.absoluteString)
    }

    func normalizedRuleTesterURL(from rawValue: String) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains(where: { $0.isWhitespace }) else {
            return nil
        }

        let candidate = value.contains("://") ? value : "https://\(value)"
        guard let url = URL(string: candidate),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false
        else {
            return nil
        }

        return url
    }

    func ruleTesterDiagnostic(for url: URL, configuration: RouterConfiguration) -> String? {
        let enabledRules = configuration.routingRules.filter(\.isEnabled)
        guard !enabledRules.isEmpty else {
            return L("No enabled rules. Turn on a rule or add one to test routing.")
        }

        let host = url.host?.lowercased() ?? ""

        for rule in enabledRules {
            if let pathPrefix = rule.pathPrefix, !pathPrefix.hasPrefix("/") {
                return L("Rule \"%@\" uses Path Starts With: %@, but path matches need a leading slash and only check the URL path. For %@, use Domain Suffix: %@ or Domain Contains: %@.", rule.name, pathPrefix, host, hostWithoutWWW(host), hostKeyword(host))
            }
        }

        if let selectedRule = selectedRuleForTesterDiagnostic(configuration: configuration) {
            return mismatchDescription(for: selectedRule, url: url)
        }

        return nil
    }

    func selectedRuleForTesterDiagnostic(configuration: RouterConfiguration) -> RoutingRule? {
        let row = rulesTableView.selectedRow
        guard row >= 0, row < configuration.routingRules.count else {
            return configuration.routingRules.first(where: \.isEnabled)
        }

        let rule = configuration.routingRules[row]
        return rule.isEnabled ? rule : configuration.routingRules.first(where: \.isEnabled)
    }

    func mismatchDescription(for rule: RoutingRule, url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.isEmpty ? "/" : url.path

        if let hostSuffix = rule.hostSuffix?.lowercased() {
            let normalized = hostSuffix.hasPrefix(".") ? String(hostSuffix.dropFirst()) : hostSuffix
            if host != normalized && !host.hasSuffix(".\(normalized)") {
                return L("Rule \"%@\" did not match: Domain Suffix is %@, but the tested domain is %@.", rule.name, hostSuffix, host)
            }
        }

        if let hostContains = rule.hostContains?.lowercased(), !host.contains(hostContains) {
            return L("Rule \"%@\" did not match: Domain Contains is %@, but the tested domain is %@.", rule.name, hostContains, host)
        }

        if let pathPrefix = rule.pathPrefix, !path.hasPrefix(pathPrefix) {
            return L("Rule \"%@\" did not match: Path Starts With checks %@, not the domain. To match %@, use Domain Suffix: %@ or Domain Contains: %@.", rule.name, path, host, hostWithoutWWW(host), hostKeyword(host))
        }

        if let urlContains = rule.urlContains?.lowercased() {
            let absolute = url.absoluteString.removingPercentEncoding ?? url.absoluteString
            if !absolute.lowercased().contains(urlContains) {
                return L("Rule \"%@\" did not match: Full URL Contains is %@, but that text is not in the tested URL.", rule.name, urlContains)
            }
        }

        return nil
    }

    func hostWithoutWWW(_ host: String) -> String {
        host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    func hostKeyword(_ host: String) -> String {
        let host = hostWithoutWWW(host)
        return host.split(separator: ".").first.map(String.init) ?? host
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        if tableView === browsersTableView {
            let item = NSPasteboardItem()
            item.setString(String(row), forType: NSPasteboard.PasteboardType("com.khalil.browserrouter.browser-row"))
            return item
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard tableView === browsersTableView else { return [] }
        if dropOperation == .above {
            return .move
        }
        return []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard tableView === browsersTableView else { return false }
        guard let item = info.draggingPasteboard.pasteboardItems?.first,
              let rowString = item.string(forType: NSPasteboard.PasteboardType("com.khalil.browserrouter.browser-row")),
              let sourceRow = Int(rowString) else {
            return false
        }

        var destinationRow = row
        if sourceRow < destinationRow {
            destinationRow -= 1
        }

        let movedOption = configuration.browserOptions.remove(at: sourceRow)
        configuration.browserOptions.insert(movedOption, at: destinationRow)

        browsersTableView.reloadData()
        _ = persistConfiguration(statusMessage: L("Browser order updated automatically"))
        reloadControls()
        return true
    }
}
