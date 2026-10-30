import AppKit
import BrowserRouterCore

private let ruleEditorSheetWidth = CGFloat(460.0)
private let ruleEditorFieldWidth = CGFloat(300.0)

extension SettingsWindowController {
    /// Opens the rule form as a sheet. Pass `nil` to create a new rule, or a row index to edit that rule.
    func presentRuleEditor(editing index: Int?) {
        guard let window, ruleEditorSheet == nil || ruleEditorSheet?.sheetParent == nil else {
            return
        }

        populateSourceAppPopup()
        editingRuleIndex = index
        if let index, index < configuration.routingRules.count {
            populateRuleForm(from: configuration.routingRules[index])
            ruleEditorTitleLabel.stringValue = L("Edit Rule")
            ruleEditorConfirmButton.title = L("Save")
        } else {
            clearRuleForm()
            ruleEditorTitleLabel.stringValue = L("New Rule")
            ruleEditorConfirmButton.title = L("Add Rule")
        }
        updateRuleEditorSheetState()

        let sheet = ruleEditorSheet ?? makeRuleEditorSheet()
        ruleEditorSheet = sheet
        window.beginSheet(sheet) { [weak self] _ in
            self?.editingRuleIndex = nil
        }
        sheet.makeFirstResponder(ruleMatchValueField)
    }

    private func makeRuleEditorSheet() -> NSWindow {
        let sheet = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: ruleEditorSheetWidth, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        sheet.isReleasedWhenClosed = false

        let matchRow = NSStackView(views: [ruleMatchTypePopup, ruleMatchValueField])
        matchRow.orientation = .horizontal
        matchRow.alignment = .firstBaseline
        matchRow.spacing = 8
        matchRow.translatesAutoresizingMaskIntoConstraints = false

        let grid = NSGridView(views: [
            [ruleEditorFormLabel(L("Name")), ruleNameField],
            [ruleEditorFormLabel(L("Condition")), matchRow],
            [NSGridCell.emptyContentView, ruleEditorHintLabel],
            [ruleEditorFormLabel(L("Open with")), ruleBrowserPopup],
            [ruleEditorFormLabel(L("Source App")), ruleSourceAppPopup]
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.row(at: 2).topPadding = -4
        grid.translatesAutoresizingMaskIntoConstraints = false

        // Without a preferred width the wrapping hint reserves height for a much narrower layout.
        ruleEditorHintLabel.preferredMaxLayoutWidth = ruleEditorFieldWidth
        ruleNameField.placeholderString = L("Optional. Defaults to the match value.")
        ruleMatchTypePopup.setContentHuggingPriority(.required, for: .horizontal)

        let cancelButton = NSButton(title: L("Cancel"), target: self, action: #selector(cancelRuleEditor))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        ruleEditorConfirmButton.target = self
        ruleEditorConfirmButton.action = #selector(confirmRuleEditor)
        ruleEditorConfirmButton.bezelStyle = .rounded
        ruleEditorConfirmButton.keyEquivalent = "\r"
        ruleEditorConfirmButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonSpacer = NSView()
        buttonSpacer.translatesAutoresizingMaskIntoConstraints = false
        buttonSpacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let buttonRow = NSStackView(views: [buttonSpacer, cancelButton, ruleEditorConfirmButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [ruleEditorTitleLabel, grid, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.setCustomSpacing(20, after: grid)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(stack)
        sheet.contentView = contentView

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: ruleEditorSheetWidth),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            ruleNameField.widthAnchor.constraint(equalToConstant: ruleEditorFieldWidth),
            matchRow.widthAnchor.constraint(equalToConstant: ruleEditorFieldWidth),
            ruleEditorHintLabel.widthAnchor.constraint(equalToConstant: ruleEditorFieldWidth),
            ruleBrowserPopup.widthAnchor.constraint(equalToConstant: ruleEditorFieldWidth),
            ruleSourceAppPopup.widthAnchor.constraint(equalToConstant: ruleEditorFieldWidth),
            ruleMatchValueField.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])

        return sheet
    }

    private func ruleEditorFormLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        return label
    }

    /// Keeps the confirm button and the hint under the match row in sync with the form.
    func updateRuleEditorSheetState() {
        let draft = ruleDraftFromForm()
        let isValid = draft.map { validateRuleDraft($0, showsAlert: false) } ?? false
        ruleEditorConfirmButton.isEnabled = isValid

        let matchField = selectedRuleMatchField() ?? .hostSuffix
        if let draft, !isValid, draft.matchField == .pathPrefix {
            ruleEditorHintLabel.stringValue = L("Path Starts With needs a leading slash, like /docs. To match a domain, choose Domain Suffix.")
            ruleEditorHintLabel.textColor = .systemOrange
        } else {
            ruleEditorHintLabel.stringValue = matchField.helpText
            ruleEditorHintLabel.textColor = .secondaryLabelColor
        }
    }

    @objc func cancelRuleEditor() {
        closeRuleEditor()
    }

    @objc func confirmRuleEditor() {
        guard let draft = ruleDraftFromForm(), validateRuleDraft(draft, showsAlert: false) else {
            updateRuleEditorSheetState()
            NSSound.beep()
            return
        }

        if let index = editingRuleIndex, index < configuration.routingRules.count {
            updateRule(at: index, with: draft)
        } else {
            addRule(from: draft)
        }
        closeRuleEditor()
    }

    private func closeRuleEditor() {
        guard let sheet = ruleEditorSheet, let parent = sheet.sheetParent else {
            return
        }

        parent.endSheet(sheet)
    }
}
