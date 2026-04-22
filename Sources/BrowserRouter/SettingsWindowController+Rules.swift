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

        if identifier == "enabled" {
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleRuleEnabled(_:)))
            checkbox.state = rule.isEnabled ? .on : .off
            checkbox.tag = row
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            return checkbox
        }

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
        cell.textColor = rule.isEnabled ? .labelColor : .tertiaryLabelColor
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
        _ = persistConfiguration(statusMessage: configuration.routingRules[row].isEnabled ? "Rule enabled" : "Rule disabled")
    }

    @objc func addRule() {
        guard let draft = ruleDraftFromForm() else {
            showMessage("Missing Rule Info", "Choose a match type, add a match value, and choose a browser/profile.")
            return
        }
        guard validateRuleDraft(draft, showsAlert: true) else {
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
        updateRuleTesterResult()
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
        guard validateRuleDraft(draft, showsAlert: true) else {
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
        updateRuleTesterResult()
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
        updateRuleTesterResult()
    }

    func validateRuleDraft(_ draft: (matchField: RuleMatchField, matchValue: String, browserID: String), showsAlert: Bool) -> Bool {
        if draft.matchField == .pathPrefix, !draft.matchValue.hasPrefix("/") {
            if showsAlert {
                showMessage(
                    "Path Match Needs A Slash",
                    "Path Starts With matches the URL path after the domain. Use a value like /docs. To match baidu.com, choose Domain Suffix and enter baidu.com."
                )
            }
            return false
        }

        return true
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
            return
        }

        guard !isPopulatingRuleForm else {
            return
        }

        _ = autosaveSelectedRuleIfPossible(statusMessage: "Selected rule updated automatically")
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === ruleTesterURLField else {
            return
        }

        updateRuleTesterResult()
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
        guard validateRuleDraft(draft, showsAlert: false) else {
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
        updateRuleTesterResult()
        rulesTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        return persistConfiguration(statusMessage: statusMessage)
    }

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
            ruleTesterResultLabel.stringValue = "Paste a URL to preview routing."
            ruleTesterResultLabel.textColor = .secondaryLabelColor
            return
        }

        guard let url = normalizedRuleTesterURL(from: rawValue) else {
            ruleTesterResultLabel.stringValue = "Enter a valid URL or domain, such as www.baidu.com."
            ruleTesterResultLabel.textColor = .systemOrange
            return
        }

        let availableOptionIDs = Set(visibleBrowserOptions.map(\.id))
        let chooserModifier = ChooserModifier(rawValue: configuration.chooserModifier) ?? .commandShift
        let resolution = RouteResolver.resolve(
            url: url,
            configuration: configuration,
            availableOptionIDs: availableOptionIDs,
            chooserOverride: chooserModifier == .always
        )

        let chooserText = chooserModifier == .always
            ? "Chooser override: always on."
            : "Chooser override: hold \(chooserModifier.title)."
        let normalizedText = normalizedRuleTesterPrefix(rawValue: rawValue, url: url)

        switch resolution {
        case .chooserOverride:
            ruleTesterResultLabel.stringValue = "\(normalizedText)\(chooserText) Routing rules will not run."
            ruleTesterResultLabel.textColor = .secondaryLabelColor
        case .matchedRule(let rule, let option):
            ruleTesterResultLabel.stringValue = "\(normalizedText)Matched rule: \(rule.name). Target: \(option.name). \(chooserText)"
            ruleTesterResultLabel.textColor = .secondaryLabelColor
        case .unavailableRule(let rule, let option):
            let targetName = option?.name ?? rule.browserOptionID
            ruleTesterResultLabel.stringValue = "\(normalizedText)Matched rule: \(rule.name). Target unavailable: \(targetName). BrowserRouter will use fallback/default routing."
            ruleTesterResultLabel.textColor = .systemOrange
        case .defaultRoute(let option):
            let diagnostic = ruleTesterDiagnostic(for: url)
            ruleTesterResultLabel.stringValue = diagnostic.map { normalizedText + $0 }
                ?? "\(normalizedText)No enabled rule matched. Default target: \(option.name). \(chooserText)"
            ruleTesterResultLabel.textColor = diagnostic == nil ? .secondaryLabelColor : .systemOrange
        case .unavailableDefault(let option):
            let targetName = option?.name ?? configuration.defaultOptionID
            let diagnostic = ruleTesterDiagnostic(for: url)
            ruleTesterResultLabel.stringValue = diagnostic.map { normalizedText + $0 }
                ?? "\(normalizedText)No enabled rule matched. Default target unavailable: \(targetName). BrowserRouter will use another available browser."
            ruleTesterResultLabel.textColor = .systemOrange
        case .fallback(let option):
            let diagnostic = ruleTesterDiagnostic(for: url)
            ruleTesterResultLabel.stringValue = diagnostic.map { normalizedText + $0 }
                ?? "\(normalizedText)No enabled rule matched. Configured default is missing, so BrowserRouter will use \(option.name)."
            ruleTesterResultLabel.textColor = .systemOrange
        case .noOptions:
            let diagnostic = ruleTesterDiagnostic(for: url)
            ruleTesterResultLabel.stringValue = diagnostic.map { normalizedText + $0 }
                ?? "\(normalizedText)No enabled rule matched and no default browser/profile is configured."
            ruleTesterResultLabel.textColor = .systemRed
        }
    }

    func normalizedRuleTesterPrefix(rawValue: String, url: URL) -> String {
        rawValue.contains("://") ? "" : "Testing as \(url.absoluteString). "
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

    func ruleTesterDiagnostic(for url: URL) -> String? {
        let enabledRules = configuration.routingRules.filter(\.isEnabled)
        guard !enabledRules.isEmpty else {
            return "No enabled rules. Turn on a rule or add one to test routing."
        }

        let host = url.host?.lowercased() ?? ""

        for rule in enabledRules {
            if let pathPrefix = rule.pathPrefix, !pathPrefix.hasPrefix("/") {
                return "Rule \"\(rule.name)\" uses Path Starts With: \(pathPrefix), but path matches need a leading slash and only check the URL path. For \(host), use Domain Suffix: \(hostWithoutWWW(host)) or Domain Contains: \(hostKeyword(host))."
            }
        }

        if let selectedRule = selectedRuleForTesterDiagnostic() {
            return mismatchDescription(for: selectedRule, url: url)
        }

        return nil
    }

    func selectedRuleForTesterDiagnostic() -> RoutingRule? {
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
                return "Rule \"\(rule.name)\" did not match: Domain Suffix is \(hostSuffix), but the tested domain is \(host)."
            }
        }

        if let hostContains = rule.hostContains?.lowercased(), !host.contains(hostContains) {
            return "Rule \"\(rule.name)\" did not match: Domain Contains is \(hostContains), but the tested domain is \(host)."
        }

        if let pathPrefix = rule.pathPrefix, !path.hasPrefix(pathPrefix) {
            return "Rule \"\(rule.name)\" did not match: Path Starts With checks \(path), not the domain. To match \(host), use Domain Suffix: \(hostWithoutWWW(host)) or Domain Contains: \(hostKeyword(host))."
        }

        if let urlContains = rule.urlContains?.lowercased() {
            let absolute = url.absoluteString.removingPercentEncoding ?? url.absoluteString
            if !absolute.lowercased().contains(urlContains) {
                return "Rule \"\(rule.name)\" did not match: Full URL Contains is \(urlContains), but that text is not in the tested URL."
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
}
