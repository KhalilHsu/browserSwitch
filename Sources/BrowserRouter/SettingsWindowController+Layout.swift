import AppKit

private let formRowSpacing = CGFloat(12.0)
private let formLabelWidth = CGFloat(160.0)
private let settingsWindowMinimumSize = NSSize(width: 620, height: 240)
private let settingsSummaryFontSize = CGFloat(12.0)
private let rulesEnabledColumnWidth = CGFloat(44.0)
private let rulesNameColumnWidth = CGFloat(108.0)
private let rulesMatchColumnWidth = CGFloat(154.0)
private let rulesBrowserColumnWidth = CGFloat(164.0)
private let rulesTableRowHeight = CGFloat(28.0)
private let rulesTableIntercellSpacing = NSSize(width: 8, height: 4)
private let aboutLogoFontSize = CGFloat(34.0)
private let aboutDescriptionFontSize = CGFloat(14.0)
private let aboutDescriptionWidthInset = CGFloat(64.0)
private let aboutVersionFontSize = CGFloat(13.0)
private let ruleButtonStackSpacing = CGFloat(8.0)
private let advancedHintFontSize = CGFloat(12.0)
private let aboutVersionLabelFontSize = CGFloat(12.0)

extension SettingsWindowController {
    func formRow(label: NSTextField, control: NSView) -> NSView {
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = formRowSpacing
        row.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: formLabelWidth).isActive = true
        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return row
    }

    func makeButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    func configureMacOSStylePreferences(in contentView: NSView) {
        guard let window else {
            return
        }

        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .preference
            window.titlebarSeparatorStyle = .none
        }
        window.minSize = settingsWindowMinimumSize
        window.center()

        showDockIconCheckBox.target = self
        showDockIconCheckBox.action = #selector(presentationChanged)
        showDockIconCheckBox.translatesAutoresizingMaskIntoConstraints = false
        showStatusItemCheckBox.target = self
        showStatusItemCheckBox.action = #selector(presentationChanged)
        showStatusItemCheckBox.translatesAutoresizingMaskIntoConstraints = false

        defaultBrowserLabel.translatesAutoresizingMaskIntoConstraints = false
        defaultBrowserPopup.translatesAutoresizingMaskIntoConstraints = false
        defaultBrowserPopup.target = self
        defaultBrowserPopup.action = #selector(defaultBrowserChanged)

        chooserModifierLabel.translatesAutoresizingMaskIntoConstraints = false
        modifierPopup.translatesAutoresizingMaskIntoConstraints = false
        modifierPopup.target = self
        modifierPopup.action = #selector(modifierChanged)

        shortcutRecorderButton.isHidden = true
        shortcutRecorderButton.onRecorded = { [weak self] shortcut in
            self?.shortcutRecorded(shortcut)
        }

        browserSummaryLabel.textColor = .secondaryLabelColor
        browserSummaryLabel.font = .systemFont(ofSize: settingsSummaryFontSize)
        browserSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        ruleSummaryLabel.textColor = .secondaryLabelColor
        ruleSummaryLabel.font = .systemFont(ofSize: settingsSummaryFontSize)
        ruleSummaryLabel.translatesAutoresizingMaskIntoConstraints = false

        rulesTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled")))
        rulesTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")))
        rulesTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("match")))
        rulesTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("browser")))
        rulesTableView.tableColumns[0].title = "On"
        rulesTableView.tableColumns[0].width = rulesEnabledColumnWidth
        rulesTableView.tableColumns[1].title = "Rule"
        rulesTableView.tableColumns[1].width = rulesNameColumnWidth
        rulesTableView.tableColumns[2].title = "Match"
        rulesTableView.tableColumns[2].width = rulesMatchColumnWidth
        rulesTableView.tableColumns[3].title = "Browser/Profile"
        rulesTableView.tableColumns[3].width = rulesBrowserColumnWidth
        rulesTableView.delegate = self
        rulesTableView.dataSource = self
        rulesTableView.usesAlternatingRowBackgroundColors = true
        rulesTableView.allowsMultipleSelection = false
        rulesTableView.rowHeight = rulesTableRowHeight
        rulesTableView.intercellSpacing = rulesTableIntercellSpacing
        rulesTableView.action = #selector(selectRule)
        rulesTableView.target = self

        ruleNameField.placeholderString = "Rule name"
        ruleNameField.translatesAutoresizingMaskIntoConstraints = false
        ruleNameField.delegate = self
        ruleMatchTypePopup.translatesAutoresizingMaskIntoConstraints = false
        ruleMatchTypePopup.target = self
        ruleMatchTypePopup.action = #selector(ruleMatchTypeChanged)
        ruleMatchTypePopup.removeAllItems()
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

        ruleTesterURLField.placeholderString = "Paste a URL or domain, e.g. www.baidu.com"
        ruleTesterURLField.translatesAutoresizingMaskIntoConstraints = false
        ruleTesterURLField.delegate = self
        ruleTesterResultLabel.font = .systemFont(ofSize: settingsSummaryFontSize)
        ruleTesterResultLabel.textColor = .secondaryLabelColor
        ruleTesterResultLabel.lineBreakMode = .byWordWrapping
        ruleTesterResultLabel.maximumNumberOfLines = 3
        ruleTesterResultLabel.translatesAutoresizingMaskIntoConstraints = false

        aboutLogoLabel.font = .systemFont(ofSize: aboutLogoFontSize, weight: .light)
        aboutLogoLabel.alignment = .left
        aboutLogoLabel.translatesAutoresizingMaskIntoConstraints = false

        aboutDescriptionLabel.font = .systemFont(ofSize: aboutDescriptionFontSize)
        aboutDescriptionLabel.textColor = .secondaryLabelColor
        aboutDescriptionLabel.alignment = .left
        aboutDescriptionLabel.lineBreakMode = .byWordWrapping
        aboutDescriptionLabel.maximumNumberOfLines = 0
        aboutDescriptionLabel.preferredMaxLayoutWidth = settingsTabContentWidth - aboutDescriptionWidthInset
        aboutDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        aboutVersionLabel.font = .systemFont(ofSize: aboutVersionFontSize, weight: .regular)
        aboutVersionLabel.alignment = .center
        aboutVersionLabel.translatesAutoresizingMaskIntoConstraints = false

        aboutGitHubButton.target = self
        aboutGitHubButton.action = #selector(openGitHub)
        aboutGitHubButton.bezelStyle = .rounded
        aboutGitHubButton.translatesAutoresizingMaskIntoConstraints = false

        aboutWebsiteButton.title = "Releases"
        aboutWebsiteButton.target = self
        aboutWebsiteButton.action = #selector(openReleases)
        aboutWebsiteButton.bezelStyle = .rounded
        aboutWebsiteButton.translatesAutoresizingMaskIntoConstraints = false

        buildBasicPage()
        buildAppearancePage()
        buildRulesPage(
            rulesScrollView: makeRulesScrollView(),
            ruleButtonStack: makeRuleButtonStack()
        )
        buildAdvancedPage(
            advancedHintLabel: makeAdvancedHintLabel(),
            refreshButton: makeRefreshButton(),
            detectButton: makeDetectButton(),
            revealButton: makeRevealButton(),
            restoreButton: makeRestoreDefaultBrowserButton()
        )
        buildAboutPage(versionStaticLabel: makeAboutVersionLabel())

        settingsTabViewController.tabStyle = .toolbar
        settingsTabViewController.transitionOptions = []
        settingsTabViewController.tabViewItems.forEach { settingsTabViewController.removeTabViewItem($0) }

        addTab(
            title: "Basic",
            symbolName: "gearshape",
            view: basicPageView,
            size: preferredContentSize(for: .basic)
        )
        addTab(
            title: "Appearance",
            symbolName: "paintbrush",
            view: appearancePageView,
            size: preferredContentSize(for: .appearance)
        )
        addTab(
            title: "Rules",
            symbolName: "list.bullet.rectangle",
            view: rulesPageView,
            size: preferredContentSize(for: .rules)
        )
        addTab(
            title: "Advanced",
            symbolName: "slider.horizontal.3",
            view: advancedPageView,
            size: preferredContentSize(for: .advanced)
        )
        addTab(
            title: "About",
            symbolName: "info.circle",
            view: aboutPageView,
            size: preferredContentSize(for: .about)
        )

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = .clear
        window.contentViewController = settingsTabViewController
        settingsTabViewController.selectedTabViewItemIndex = 0
        updateAboutVersion()
    }

    func preferredContentSize(for tab: SettingsTab) -> NSSize {
        let view: NSView
        switch tab {
        case .basic: view = basicPageView
        case .appearance: view = appearancePageView
        case .rules: view = rulesPageView
        case .advanced: view = advancedPageView
        case .about: view = aboutPageView
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: settingsTabContentWidth).isActive = true
        view.layoutSubtreeIfNeeded()
        return NSSize(width: settingsTabContentWidth, height: view.fittingSize.height)
    }

    func addTab(title: String, symbolName: String, view: NSView, size: NSSize) {
        let controller = NSViewController()
        controller.view = view
        controller.preferredContentSize = size
        view.translatesAutoresizingMaskIntoConstraints = true
        view.autoresizingMask = [.width, .minYMargin]

        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        settingsTabViewController.addTabViewItem(item)
    }

    func makeRulesScrollView() -> NSScrollView {
        let rulesScrollView = NSScrollView()
        rulesScrollView.hasVerticalScroller = true
        rulesScrollView.documentView = rulesTableView
        rulesScrollView.translatesAutoresizingMaskIntoConstraints = false
        return rulesScrollView
    }

    func makeRuleButtonStack() -> NSStackView {
        let addRuleButton = makeButton("Add Rule", action: #selector(addRule))
        let updateRuleButton = makeButton("Update Selected", action: #selector(updateSelectedRule))
        let removeRuleButton = makeButton("Remove Selected", action: #selector(removeSelectedRule))
        addRuleButton.keyEquivalent = "\r"
        let ruleButtonStack = NSStackView(views: [addRuleButton, updateRuleButton, removeRuleButton])
        ruleButtonStack.orientation = .horizontal
        ruleButtonStack.spacing = ruleButtonStackSpacing
        ruleButtonStack.translatesAutoresizingMaskIntoConstraints = false
        return ruleButtonStack
    }

    func makeAdvancedHintLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "Use this page for browser inventory and the config file.")
        label.font = .systemFont(ofSize: advancedHintFontSize)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    func makeRefreshButton() -> NSButton {
        makeButton("Refresh Browsers", action: #selector(refreshBrowsers))
    }

    func makeDetectButton() -> NSButton {
        makeButton("Detect Profiles", action: #selector(detectProfiles))
    }

    func makeRevealButton() -> NSButton {
        makeButton("Open Config", action: #selector(revealConfigFile))
    }

    func makeRestoreDefaultBrowserButton() -> NSButton {
        makeButton("Restore Previous Default Browser", action: #selector(restorePreviousDefaultBrowser))
    }

    func makeAboutVersionLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "Version")
        label.font = .systemFont(ofSize: aboutVersionLabelFontSize, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
}
