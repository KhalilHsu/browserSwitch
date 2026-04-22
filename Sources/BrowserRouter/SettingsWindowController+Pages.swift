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

        stack.addArrangedSubview(formRow(label: defaultBrowserLabel, control: defaultBrowserPopup))
        stack.addArrangedSubview(formRow(label: chooserModifierLabel, control: modifierPopup))
        stack.addArrangedSubview(browserSummaryLabel)

        basicPageView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: basicPageView.topAnchor, constant: settingsPageTopPadding),
            stack.leadingAnchor.constraint(equalTo: basicPageView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: basicPageView.trailingAnchor, constant: -32),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: basicPageView.bottomAnchor, constant: -settingsPageVerticalPadding),

            // Make both popup buttons the same width so they align
            modifierPopup.widthAnchor.constraint(equalTo: defaultBrowserPopup.widthAnchor)
        ])
    }

    func buildAppearancePage() {
        let introLabel = NSTextField(labelWithString: "Keep BrowserRouter light or show it in more places.")
        introLabel.font = .systemFont(ofSize: 13)
        introLabel.textColor = .secondaryLabelColor
        introLabel.translatesAutoresizingMaskIntoConstraints = false

        let togglesStack = NSStackView(views: [showDockIconCheckBox, showStatusItemCheckBox])
        togglesStack.orientation = .horizontal
        togglesStack.alignment = .centerY
        togglesStack.spacing = 24
        togglesStack.translatesAutoresizingMaskIntoConstraints = false

        let noteLabel = NSTextField(labelWithString: "Skin options can grow here later without touching routing or rules.")
        noteLabel.font = .systemFont(ofSize: 12)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [introLabel, togglesStack, noteLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        appearancePageContentStack = stack

        appearancePageView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: appearancePageView.topAnchor, constant: settingsPageTopPadding),
            stack.leadingAnchor.constraint(equalTo: appearancePageView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: appearancePageView.trailingAnchor, constant: -32),
            stack.bottomAnchor.constraint(equalTo: appearancePageView.bottomAnchor, constant: -settingsPageVerticalPadding)
        ])
    }

    func buildRulesPage(rulesScrollView: NSScrollView, ruleButtonStack: NSStackView) {
        let headerLabel = NSTextField(labelWithString: "Rules decide where a link goes before it opens.")
        headerLabel.font = .systemFont(ofSize: 13)
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        let rulesHeaderStack = NSStackView(views: [headerLabel, ruleSummaryLabel])
        rulesHeaderStack.orientation = .horizontal
        rulesHeaderStack.alignment = .centerY
        rulesHeaderStack.spacing = 12
        rulesHeaderStack.translatesAutoresizingMaskIntoConstraints = false

        let ruleNameLabel = NSTextField(labelWithString: "Rule name")
        ruleNameLabel.font = .systemFont(ofSize: 12)
        ruleNameLabel.textColor = .secondaryLabelColor
        ruleNameLabel.translatesAutoresizingMaskIntoConstraints = false

        let matchLabel = NSTextField(labelWithString: "Match")
        matchLabel.font = .systemFont(ofSize: 12)
        matchLabel.textColor = .secondaryLabelColor
        matchLabel.translatesAutoresizingMaskIntoConstraints = false

        let browserLabel = NSTextField(labelWithString: "Browser/Profile")
        browserLabel.font = .systemFont(ofSize: 12)
        browserLabel.textColor = .secondaryLabelColor
        browserLabel.translatesAutoresizingMaskIntoConstraints = false

        let compactRuleNameRow = NSStackView(views: [ruleNameLabel, ruleNameField])
        compactRuleNameRow.orientation = .horizontal
        compactRuleNameRow.alignment = .centerY
        compactRuleNameRow.spacing = 12
        compactRuleNameRow.translatesAutoresizingMaskIntoConstraints = false

        let compactMatchRow = NSStackView(views: [matchLabel, ruleMatchTypePopup, ruleMatchValueField])
        compactMatchRow.orientation = .horizontal
        compactMatchRow.alignment = .centerY
        compactMatchRow.spacing = 12
        compactMatchRow.translatesAutoresizingMaskIntoConstraints = false

        let compactBrowserRow = NSStackView(views: [browserLabel, ruleBrowserPopup])
        compactBrowserRow.orientation = .horizontal
        compactBrowserRow.alignment = .centerY
        compactBrowserRow.spacing = 12
        compactBrowserRow.translatesAutoresizingMaskIntoConstraints = false

        let editorStack = NSStackView(views: [compactRuleNameRow, compactMatchRow, compactBrowserRow, ruleButtonStack])
        editorStack.orientation = .vertical
        editorStack.alignment = .leading
        editorStack.spacing = 10
        editorStack.translatesAutoresizingMaskIntoConstraints = false

        ruleNameLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true
        matchLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true
        browserLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true
        ruleMatchTypePopup.widthAnchor.constraint(equalToConstant: 128).isActive = true
        ruleMatchValueField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        ruleMatchValueField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        ruleBrowserPopup.setContentHuggingPriority(.required, for: .horizontal)
        ruleBrowserPopup.setContentCompressionResistancePriority(.required, for: .horizontal)

        let pageStack = NSStackView(views: [rulesHeaderStack, rulesScrollView, editorStack])
        pageStack.orientation = .vertical
        pageStack.alignment = .leading
        pageStack.spacing = 0
        pageStack.translatesAutoresizingMaskIntoConstraints = false
        rulesPageContentStack = pageStack

        rulesPageView.addSubview(pageStack)

        NSLayoutConstraint.activate([
            pageStack.topAnchor.constraint(equalTo: rulesPageView.topAnchor, constant: settingsPageTopPadding),
            pageStack.leadingAnchor.constraint(equalTo: rulesPageView.leadingAnchor, constant: 32),
            pageStack.trailingAnchor.constraint(equalTo: rulesPageView.trailingAnchor, constant: -32),
            pageStack.bottomAnchor.constraint(equalTo: rulesPageView.bottomAnchor, constant: -settingsPageVerticalPadding),

            rulesScrollView.topAnchor.constraint(equalTo: rulesHeaderStack.bottomAnchor, constant: 16),
            editorStack.topAnchor.constraint(equalTo: rulesScrollView.bottomAnchor, constant: 18),
            editorStack.bottomAnchor.constraint(lessThanOrEqualTo: rulesPageView.bottomAnchor, constant: -settingsPageVerticalPadding),

            ruleNameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            ruleMatchValueField.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            ruleBrowserPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])

        rulesScrollViewHeightConstraint = rulesScrollView.heightAnchor.constraint(equalToConstant: preferredRulesListHeight())
        rulesScrollViewHeightConstraint?.priority = .defaultHigh
        rulesScrollViewHeightConstraint?.isActive = true
    }

    func buildAdvancedPage(
        advancedHintLabel: NSTextField,
        refreshButton: NSButton,
        detectButton: NSButton,
        revealButton: NSButton,
        restoreButton: NSButton
    ) {
        let inventoryTitle = NSTextField(labelWithString: "Browser inventory")
        inventoryTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        inventoryTitle.translatesAutoresizingMaskIntoConstraints = false

        let defaultBrowserTitle = NSTextField(labelWithString: "Default browser")
        defaultBrowserTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        defaultBrowserTitle.translatesAutoresizingMaskIntoConstraints = false

        let defaultBrowserHint = NSTextField(labelWithString: "Stop routing http and https links through BrowserRouter by restoring the browser that was default before setup.")
        defaultBrowserHint.font = .systemFont(ofSize: 12)
        defaultBrowserHint.textColor = .secondaryLabelColor
        defaultBrowserHint.lineBreakMode = .byWordWrapping
        defaultBrowserHint.maximumNumberOfLines = 2
        defaultBrowserHint.translatesAutoresizingMaskIntoConstraints = false

        let configTitle = NSTextField(labelWithString: "Config file")
        configTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        configTitle.translatesAutoresizingMaskIntoConstraints = false

        let inventoryButtons = NSStackView(views: [refreshButton, detectButton])
        inventoryButtons.orientation = .horizontal
        inventoryButtons.alignment = .centerY
        inventoryButtons.spacing = 8
        inventoryButtons.translatesAutoresizingMaskIntoConstraints = false

        let configButtons = NSStackView(views: [revealButton])
        configButtons.orientation = .horizontal
        configButtons.alignment = .centerY
        configButtons.spacing = 8
        configButtons.translatesAutoresizingMaskIntoConstraints = false

        let restoreButtons = NSStackView(views: [restoreButton])
        restoreButtons.orientation = .horizontal
        restoreButtons.alignment = .centerY
        restoreButtons.spacing = 8
        restoreButtons.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [
            advancedHintLabel,
            inventoryTitle,
            inventoryButtons,
            defaultBrowserTitle,
            defaultBrowserHint,
            restoreButtons,
            configTitle,
            configButtons
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        advancedPageContentStack = stack

        advancedPageView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: advancedPageView.topAnchor, constant: settingsPageTopPadding),
            stack.leadingAnchor.constraint(equalTo: advancedPageView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: advancedPageView.trailingAnchor, constant: -32),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: advancedPageView.bottomAnchor, constant: -settingsPageVerticalPadding),
            defaultBrowserHint.widthAnchor.constraint(lessThanOrEqualToConstant: 560)
        ])
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
