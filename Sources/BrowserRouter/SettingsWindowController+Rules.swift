import AppKit
import BrowserRouterCore

extension SettingsWindowController {
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
            let match = RuleMatchField.matchDescription(for: rule)
            text = match.isEmpty ? "Any URL" : match
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
        cell.lineBreakMode = .byWordWrapping
        cell.maximumNumberOfLines = 2
        return cell
    }

    @objc func selectRule() {
        let row = rulesTableView.selectedRow
        guard row >= 0, row < configuration.routingRules.count else {
            clearRuleForm()
            return
        }

        populateRuleForm(from: configuration.routingRules[row])
    }

    @objc func addRule() {
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

    @objc func updateSelectedRule() {
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

    @objc func removeSelectedRule() {
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

    func populateRuleForm(from rule: RoutingRule) {
        isPopulatingRuleForm = true
        ruleNameField.stringValue = rule.name
        let matchField = RuleMatchField.preferredField(for: rule)
        ruleMatchTypePopup.selectItem(withRepresentedObject: matchField.rawValue)
        ruleMatchValueField.stringValue = matchField.value(from: rule) ?? ""
        updateRuleMatchPlaceholder()
        ruleBrowserPopup.selectItem(withRepresentedObject: rule.browserOptionID)
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
        isPopulatingRuleForm = false
    }

    func selectedRuleMatchField() -> RuleMatchField? {
        selectedRepresentedObject(ruleMatchTypePopup).flatMap(RuleMatchField.init(rawValue:))
    }

    func ruleDraftFromForm() -> (matchField: RuleMatchField, matchValue: String, browserID: String)? {
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

    func updateRuleMatchPlaceholder() {
        ruleMatchValueField.placeholderString = selectedRuleMatchField()?.placeholder ?? RuleMatchField.hostSuffix.placeholder
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
        guard !isPopulatingRuleForm else {
            return
        }

        _ = autosaveSelectedRuleIfPossible(statusMessage: "Selected rule updated automatically")
    }

    func windowWillClose(_ notification: Notification) {
        _ = autosaveSelectedRuleIfPossible(statusMessage: "Selected rule updated automatically")
    }

    func autosaveSelectedRuleIfPossible(statusMessage: String) -> Bool {
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
