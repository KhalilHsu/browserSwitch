import AppKit
import BrowserRouterCore

extension SettingsWindowController {
    func buildBasicPage() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        basicPageContentStack = stack

        // Build the chooser row manually so we can append the recorder button.
        let chooserControlRow = NSStackView(views: [modifierPopup, shortcutRecorderButton])
        chooserControlRow.orientation = .horizontal
        chooserControlRow.alignment = .centerY
        chooserControlRow.spacing = 8
        chooserControlRow.translatesAutoresizingMaskIntoConstraints = false

        let chooserRow = NSStackView(views: [chooserModifierLabel, chooserControlRow])
        chooserRow.orientation = .horizontal
        chooserRow.alignment = .centerY
        chooserRow.spacing = 12
        chooserRow.translatesAutoresizingMaskIntoConstraints = false
        chooserModifierLabel.translatesAutoresizingMaskIntoConstraints = false
        chooserModifierLabel.widthAnchor.constraint(equalToConstant: 160).isActive = true

        let iconTogglesStack = NSStackView(views: [showDockIconCheckBox, showStatusItemCheckBox])
        iconTogglesStack.orientation = .horizontal
        iconTogglesStack.alignment = .centerY
        iconTogglesStack.spacing = 24
        iconTogglesStack.translatesAutoresizingMaskIntoConstraints = false

        // Hints sit under their control, so they only get the width right of the label column.
        let indentedHintWidth = SettingsStyle.contentWidth - 172
        let chooserHint = SettingsStyle.hint(L("Hold this shortcut while opening a link to pick a browser for it."))
        chooserHint.preferredMaxLayoutWidth = indentedHintWidth

        stack.addArrangedSubview(formRow(label: defaultBrowserLabel, control: defaultBrowserPopup))
        stack.addArrangedSubview(formRow(label: NSTextField(labelWithString: ""), control: autoRestoreCheckBox))
        stack.addArrangedSubview(chooserRow)
        stack.addArrangedSubview(formRow(label: NSTextField(labelWithString: ""), control: chooserHint))
        stack.addArrangedSubview(formRow(label: NSTextField(labelWithString: L("Show icon in")), control: iconTogglesStack))
        stack.addArrangedSubview(formRow(label: languageLabel, control: languagePopup))
        stack.addArrangedSubview(browserSummaryLabel)
        stack.setCustomSpacing(4, after: chooserRow)
        stack.setCustomSpacing(20, after: languagePopup.superview ?? languagePopup)

        basicPageView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: basicPageView.topAnchor, constant: settingsPageTopPadding),
            stack.leadingAnchor.constraint(equalTo: basicPageView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: basicPageView.trailingAnchor, constant: -32),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: basicPageView.bottomAnchor, constant: -settingsPageVerticalPadding),

            // Keep every popup in the control column the same width.
            modifierPopup.widthAnchor.constraint(equalTo: defaultBrowserPopup.widthAnchor),
            languagePopup.widthAnchor.constraint(equalTo: defaultBrowserPopup.widthAnchor)
        ])
    }

    func buildRulesPage(rulesScrollView: NSScrollView, ruleActionBar: NSStackView) {
        let headerLabel = NSTextField(wrappingLabelWithString: L("Rules are checked from top to bottom. The first match wins."))
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.preferredMaxLayoutWidth = SettingsStyle.contentWidth - 140
        headerLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        configureButton(newRuleButton, title: L("New Rule"), action: #selector(startNewRule))
        newRuleButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        newRuleButton.imagePosition = .imageLeading

        let headerSpacer = NSView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        headerSpacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let headerTextStack = NSStackView(views: [headerLabel, ruleSummaryLabel])
        headerTextStack.orientation = .vertical
        headerTextStack.alignment = .leading
        headerTextStack.spacing = 2
        headerTextStack.translatesAutoresizingMaskIntoConstraints = false

        let rulesHeaderStack = NSStackView(views: [headerTextStack, headerSpacer, newRuleButton])
        rulesHeaderStack.orientation = .horizontal
        rulesHeaderStack.alignment = .centerY
        rulesHeaderStack.spacing = 12
        rulesHeaderStack.translatesAutoresizingMaskIntoConstraints = false

        let testerTitle = SettingsStyle.sectionTitle(L("Test a link"))

        let testerStack = NSStackView(views: [testerTitle, ruleTesterURLField, ruleTesterResultLabel])
        testerStack.orientation = .vertical
        testerStack.alignment = .leading
        testerStack.spacing = 7
        testerStack.translatesAutoresizingMaskIntoConstraints = false

        ruleTesterURLField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        ruleTesterURLField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let pageStack = NSStackView(views: [rulesHeaderStack, rulesScrollView, ruleActionBar, testerStack])
        pageStack.orientation = .vertical
        pageStack.alignment = .leading
        pageStack.spacing = 0
        pageStack.setCustomSpacing(12, after: rulesHeaderStack)
        pageStack.setCustomSpacing(8, after: rulesScrollView)
        pageStack.setCustomSpacing(24, after: ruleActionBar)
        pageStack.translatesAutoresizingMaskIntoConstraints = false
        rulesPageContentStack = pageStack

        rulesPageView.addSubview(pageStack)

        NSLayoutConstraint.activate([
            pageStack.topAnchor.constraint(equalTo: rulesPageView.topAnchor, constant: settingsPageTopPadding),
            pageStack.leadingAnchor.constraint(equalTo: rulesPageView.leadingAnchor, constant: 32),
            pageStack.trailingAnchor.constraint(equalTo: rulesPageView.trailingAnchor, constant: -32),
            pageStack.bottomAnchor.constraint(equalTo: rulesPageView.bottomAnchor, constant: -settingsPageVerticalPadding),

            rulesHeaderStack.widthAnchor.constraint(equalTo: pageStack.widthAnchor),
            rulesScrollView.widthAnchor.constraint(equalTo: pageStack.widthAnchor),
            rulesScrollView.heightAnchor.constraint(equalToConstant: 260),
            ruleActionBar.widthAnchor.constraint(equalTo: pageStack.widthAnchor),
            ruleTesterURLField.widthAnchor.constraint(equalTo: pageStack.widthAnchor),
            ruleTesterResultLabel.widthAnchor.constraint(equalTo: pageStack.widthAnchor)
        ])
    }

    func buildAdvancedPage(
        browsersScrollView: NSScrollView,
        refreshButton: NSButton,
        revealButton: NSButton,
        restoreButton: NSButton
    ) {
        SettingsStyle.styleHint(profileAccessNoteLabel)
        profileAccessSettingsButton.target = self
        profileAccessSettingsButton.action = #selector(openFullDiskAccessSettings)
        profileAccessSettingsButton.isBordered = false
        profileAccessSettingsButton.contentTintColor = .linkColor
        profileAccessSettingsButton.font = SettingsStyle.hintFont
        profileAccessSettingsButton.translatesAutoresizingMaskIntoConstraints = false

        let profileAccessNote = NSStackView(views: [profileAccessNoteLabel, profileAccessSettingsButton])
        profileAccessNote.orientation = .vertical
        profileAccessNote.alignment = .leading
        profileAccessNote.spacing = 2
        profileAccessNote.translatesAutoresizingMaskIntoConstraints = false

        let inventorySection = advancedSection(
            title: L("Browsers & Profiles"),
            hint: L("Uncheck to hide from menus. Drag to reorder."),
            content: [browsersScrollView, refreshButton, profileAccessNote]
        )
        browsersScrollView.heightAnchor.constraint(equalToConstant: 236).isActive = true
        browsersScrollView.widthAnchor.constraint(equalToConstant: SettingsStyle.contentWidth).isActive = true

        let defaultBrowserSection = advancedSection(
            title: L("System Default Browser"),
            hint: L("Hand links back to the browser that was the default before BrowserRouter."),
            content: [restoreButton]
        )

        let configSection = advancedSection(
            title: L("Configuration"),
            hint: L("Settings and rules are stored in a local JSON file."),
            content: [revealButton]
        )

        updateProfileAccessNote()

        let stack = NSStackView(views: [inventorySection, defaultBrowserSection, configSection])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        advancedPageContentStack = stack

        advancedPageView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: advancedPageView.topAnchor, constant: settingsPageTopPadding),
            stack.leadingAnchor.constraint(equalTo: advancedPageView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: advancedPageView.trailingAnchor, constant: -32),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: advancedPageView.bottomAnchor, constant: -settingsPageVerticalPadding)
        ])
    }

    /// A titled block on the Advanced page: section title, one hint line, then its controls.
    private func advancedSection(title: String, hint: String, content: [NSView]) -> NSStackView {
        let header = NSStackView(views: [SettingsStyle.sectionTitle(title), SettingsStyle.hint(hint)])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        let section = NSStackView(views: [header] + content)
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8
        section.translatesAutoresizingMaskIntoConstraints = false
        return section
    }

    func buildAboutPage(versionStaticLabel: NSTextField) {
        let titleStack = NSStackView(views: [aboutLogoLabel, aboutDescriptionLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 8
        titleStack.translatesAutoresizingMaskIntoConstraints = false

        let versionRow = NSStackView(views: [versionStaticLabel, aboutVersionLabel])
        versionRow.orientation = .horizontal
        versionRow.alignment = .centerY
        versionRow.spacing = 10
        versionRow.translatesAutoresizingMaskIntoConstraints = false

        let linkRow = NSStackView(views: [aboutGitHubButton, aboutWebsiteButton])
        linkRow.orientation = .horizontal
        linkRow.alignment = .centerY
        linkRow.spacing = 10
        linkRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [titleStack, versionRow, linkRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        aboutPageContentStack = stack

        aboutPageView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: aboutPageView.topAnchor, constant: settingsPageTopPadding),
            stack.leadingAnchor.constraint(equalTo: aboutPageView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: aboutPageView.trailingAnchor, constant: -32),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: aboutPageView.bottomAnchor, constant: -settingsPageVerticalPadding)
        ])
    }
}
