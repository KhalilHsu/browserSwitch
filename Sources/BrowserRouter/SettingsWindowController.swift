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

private final class SettingsTabViewController: NSTabViewController {
    private let backgroundVisualEffectView = NSVisualEffectView()
    private var didInstallLayout = false

    override func loadView() {
        super.loadView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installLayoutIfNeeded()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        installLayoutIfNeeded()
    }

    private func installLayoutIfNeeded() {
        guard !didInstallLayout else {
            return
        }

        didInstallLayout = true
        tabView.translatesAutoresizingMaskIntoConstraints = false
        backgroundVisualEffectView.blendingMode = .behindWindow
        backgroundVisualEffectView.material = .toolTip
        backgroundVisualEffectView.state = .followsWindowActiveState
        backgroundVisualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundVisualEffectView, positioned: .below, relativeTo: tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backgroundVisualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundVisualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundVisualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundVisualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

private let settingsToolbarHeight = CGFloat(76.0)
private let settingsTabContentWidth = CGFloat(520.0)
private let settingsPageVerticalPadding = CGFloat(24.0)
private let settingsPageTopPadding = settingsToolbarHeight + settingsPageVerticalPadding

@MainActor
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    private enum SettingsTab: String, CaseIterable {
        case basic
        case appearance
        case rules
        case advanced
        case about

        var title: String {
            switch self {
            case .basic:
                return "Basic"
            case .appearance:
                return "Appearance"
            case .rules:
                return "Rules"
            case .advanced:
                return "Advanced"
            case .about:
                return "About"
            }
        }

        var symbolName: String {
            switch self {
            case .basic:
                return "gearshape"
            case .appearance:
                return "paintbrush"
            case .rules:
                return "list.bullet.rectangle"
            case .advanced:
                return "slider.horizontal.3"
            case .about:
                return "info.circle"
            }
        }
    }

    private let onRequestSetAsDefaultBrowser: () -> Void
    private let showDockIconCheckBox = NSButton(checkboxWithTitle: "Show Dock icon", target: nil, action: nil)
    private let showStatusItemCheckBox = NSButton(checkboxWithTitle: "Show menu bar icon", target: nil, action: nil)
    private let defaultBrowserNoticeView = NSView()
    private let defaultBrowserNoticeIcon = NSImageView()
    private let defaultBrowserNoticeLabel = NSTextField(labelWithString: "Set Router as your default browser.")
    private let defaultBrowserNoticeButton = NSButton(title: "Set Default", target: nil, action: nil)
    private let defaultBrowserLabel = NSTextField(labelWithString: "Default browser/profile")
    private let chooserModifierLabel = NSTextField(labelWithString: "Show chooser when")
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
    private let headerTitleLabel = NSTextField(labelWithString: "BrowserRouter")
    private let headerSubtitleLabel = NSTextField(labelWithString: "Route external links to the browser or profile that fits the moment.")
    private let tabStripView = NSStackView()
    private let rootStackView = NSStackView()
    private let backgroundEffectView = NSVisualEffectView()
    private let pageContainerView = NSView()
    private let footerSeparatorView = NSBox()
    private let footerStackView = NSStackView()
    private let basicPageView = NSView()
    private let appearancePageView = NSView()
    private let rulesPageView = NSView()
    private let advancedPageView = NSView()
    private let aboutPageView = NSView()
    private let aboutLogoLabel = NSTextField(labelWithString: "BrowserRouter")
    private let aboutDescriptionLabel = NSTextField(labelWithString: "Regrettably, I have only made some minor contributions to the open-source community.")
    private let aboutVersionLabel = NSTextField(labelWithString: "")
    private let aboutGitHubButton = NSButton(title: "GitHub", target: nil, action: nil)
    private let aboutWebsiteButton = NSButton(title: "Project", target: nil, action: nil)
    private let settingsTabViewController = SettingsTabViewController()
    private var configuration: RouterConfiguration
    private var visibleBrowserOptions: [BrowserOption] = []
    private var isPopulatingRuleForm = false
    private var selectedTab: SettingsTab = .basic
    private var tabButtons: [SettingsTab: NSButton] = [:]
    private var pageContainerHeightConstraint: NSLayoutConstraint?
    private var rulesScrollViewHeightConstraint: NSLayoutConstraint?
    private var basicPageContentStack: NSStackView?
    private var appearancePageContentStack: NSStackView?
    private var rulesPageContentStack: NSStackView?
    private var advancedPageContentStack: NSStackView?
    private var aboutPageContentStack: NSStackView?
    private let onSave: (RouterConfiguration) -> Void

    init(
        configuration: RouterConfiguration,
        onSave: @escaping (RouterConfiguration) -> Void,
        onRequestSetAsDefaultBrowser: @escaping () -> Void = {}
    ) {
        self.configuration = configuration
        self.onSave = onSave
        self.onRequestSetAsDefaultBrowser = onRequestSetAsDefaultBrowser

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 680),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.title = "BrowserRouter"
        window.isReleasedWhenClosed = false
        window.center()
        window.minSize = NSSize(width: 720, height: 420)

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

        configureMosStylePreferences(in: contentView)
        if false {

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = .clear

        defaultBrowserNoticeView.wantsLayer = true
        defaultBrowserNoticeView.layer?.cornerRadius = 12
        defaultBrowserNoticeView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.12).cgColor
        defaultBrowserNoticeView.layer?.borderWidth = 1
        defaultBrowserNoticeView.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.18).cgColor
        defaultBrowserNoticeView.translatesAutoresizingMaskIntoConstraints = false

        defaultBrowserNoticeIcon.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        defaultBrowserNoticeIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        defaultBrowserNoticeIcon.contentTintColor = .systemBlue
        defaultBrowserNoticeIcon.translatesAutoresizingMaskIntoConstraints = false

        defaultBrowserNoticeLabel.font = .systemFont(ofSize: 13, weight: .regular)
        defaultBrowserNoticeLabel.textColor = .labelColor
        defaultBrowserNoticeLabel.lineBreakMode = .byTruncatingTail
        defaultBrowserNoticeLabel.maximumNumberOfLines = 1
        defaultBrowserNoticeLabel.translatesAutoresizingMaskIntoConstraints = false

        defaultBrowserNoticeButton.target = self
        defaultBrowserNoticeButton.action = #selector(requestSetAsDefaultBrowser)
        defaultBrowserNoticeButton.bezelStyle = .rounded
        defaultBrowserNoticeButton.translatesAutoresizingMaskIntoConstraints = false

        let noticeTextStack = NSStackView(views: [defaultBrowserNoticeLabel])
        noticeTextStack.orientation = .vertical
        noticeTextStack.alignment = .leading
        noticeTextStack.spacing = 2
        noticeTextStack.translatesAutoresizingMaskIntoConstraints = false

        let noticeStack = NSStackView(views: [defaultBrowserNoticeIcon, noticeTextStack, defaultBrowserNoticeButton])
        noticeStack.orientation = .horizontal
        noticeStack.alignment = .centerY
        noticeStack.spacing = 12
        noticeStack.translatesAutoresizingMaskIntoConstraints = false

        defaultBrowserNoticeView.addSubview(noticeStack)

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

        let detectButton = makeButton("Detect Profiles", action: #selector(detectProfiles))
        let refreshButton = makeButton("Refresh Browsers", action: #selector(refreshBrowsers))
        let revealButton = makeButton("Open Config", action: #selector(revealConfigFile))
        autosaveStatusLabel.textColor = .secondaryLabelColor
        autosaveStatusLabel.font = .systemFont(ofSize: 12)
        autosaveStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        browserSummaryLabel.textColor = .secondaryLabelColor
        browserSummaryLabel.font = .systemFont(ofSize: 12)
        browserSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        ruleSummaryLabel.textColor = .secondaryLabelColor
        ruleSummaryLabel.font = .systemFont(ofSize: 12)
        ruleSummaryLabel.translatesAutoresizingMaskIntoConstraints = false

        rulesTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")))
        rulesTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("browser")))
        rulesTableView.tableColumns[0].title = "Rule"
        rulesTableView.tableColumns[0].width = 240
        rulesTableView.tableColumns[1].title = "Browser/Profile"
        rulesTableView.tableColumns[1].width = 184
        rulesTableView.delegate = self
        rulesTableView.dataSource = self
        rulesTableView.usesAlternatingRowBackgroundColors = true
        rulesTableView.allowsMultipleSelection = false
        rulesTableView.rowHeight = 36
        rulesTableView.intercellSpacing = NSSize(width: 8, height: 4)
        rulesTableView.action = #selector(selectRule)
        rulesTableView.target = self

        let rulesScrollView = NSScrollView()
        rulesScrollView.hasVerticalScroller = true
        rulesScrollView.documentView = rulesTableView
        rulesScrollView.translatesAutoresizingMaskIntoConstraints = false

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

        tabStripView.orientation = .horizontal
        tabStripView.alignment = .top
        tabStripView.distribution = .equalSpacing
        tabStripView.spacing = 18
        tabStripView.translatesAutoresizingMaskIntoConstraints = false

        backgroundEffectView.material = .toolTip
        backgroundEffectView.blendingMode = .behindWindow
        backgroundEffectView.state = .followsWindowActiveState
        backgroundEffectView.wantsLayer = true
        backgroundEffectView.layer?.cornerRadius = 0
        backgroundEffectView.layer?.masksToBounds = true
        backgroundEffectView.translatesAutoresizingMaskIntoConstraints = false

        pageContainerView.wantsLayer = true
        pageContainerView.layer?.backgroundColor = NSColor.clear.cgColor
        pageContainerView.layer?.borderWidth = 0
        pageContainerView.layer?.shadowOpacity = 0
        pageContainerView.translatesAutoresizingMaskIntoConstraints = false

        footerSeparatorView.boxType = .separator
        footerSeparatorView.translatesAutoresizingMaskIntoConstraints = false

        footerStackView.orientation = .horizontal
        footerStackView.alignment = .centerY
        footerStackView.spacing = 12
        footerStackView.distribution = .fill
        footerStackView.translatesAutoresizingMaskIntoConstraints = false

        let advancedHintLabel = NSTextField(labelWithString: "Use this page for browser inventory and the config file.")
        advancedHintLabel.font = .systemFont(ofSize: 12)
        advancedHintLabel.textColor = .secondaryLabelColor
        advancedHintLabel.translatesAutoresizingMaskIntoConstraints = false

        let aboutVersionStaticLabel = NSTextField(labelWithString: "Version")
        aboutVersionStaticLabel.font = .systemFont(ofSize: 12, weight: .medium)
        aboutVersionStaticLabel.textColor = .secondaryLabelColor
        aboutVersionStaticLabel.translatesAutoresizingMaskIntoConstraints = false

        aboutLogoLabel.font = .systemFont(ofSize: 34, weight: .light)
        aboutLogoLabel.alignment = .left
        aboutLogoLabel.translatesAutoresizingMaskIntoConstraints = false

        aboutDescriptionLabel.font = .systemFont(ofSize: 14)
        aboutDescriptionLabel.textColor = .secondaryLabelColor
        aboutDescriptionLabel.alignment = .left
        aboutDescriptionLabel.lineBreakMode = .byWordWrapping
        aboutDescriptionLabel.maximumNumberOfLines = 2
        aboutDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        aboutVersionLabel.font = .systemFont(ofSize: 13, weight: .regular)
        aboutVersionLabel.alignment = .left
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

        [basicPageView, appearancePageView, rulesPageView, advancedPageView, aboutPageView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentView.addSubview(backgroundEffectView)
        rootStackView.orientation = .vertical
        rootStackView.alignment = .centerX
        rootStackView.spacing = 14
        rootStackView.translatesAutoresizingMaskIntoConstraints = false
        rootStackView.addArrangedSubview(tabStripView)
        rootStackView.addArrangedSubview(pageContainerView)
        rootStackView.addArrangedSubview(footerSeparatorView)
        rootStackView.addArrangedSubview(footerStackView)
        contentView.addSubview(rootStackView)
        pageContainerView.addSubview(basicPageView)
        pageContainerView.addSubview(appearancePageView)
        pageContainerView.addSubview(rulesPageView)
        pageContainerView.addSubview(advancedPageView)
        pageContainerView.addSubview(aboutPageView)

        let footerSpacer = NSView()
        footerSpacer.translatesAutoresizingMaskIntoConstraints = false
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        footerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        autosaveStatusLabel.textColor = .secondaryLabelColor
        autosaveStatusLabel.font = .systemFont(ofSize: 12)
        autosaveStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        let doneButton = makeButton("Done", action: #selector(closeWindow))
        doneButton.keyEquivalent = "\r"

        footerStackView.addArrangedSubview(autosaveStatusLabel)
        footerStackView.addArrangedSubview(footerSpacer)
        footerStackView.addArrangedSubview(doneButton)

        buildTabStrip()
        buildBasicPage()
        buildAppearancePage()
        buildRulesPage(rulesScrollView: rulesScrollView, ruleButtonStack: ruleButtonStack)
        buildAdvancedPage(advancedHintLabel: advancedHintLabel, refreshButton: refreshButton, detectButton: detectButton, revealButton: revealButton)
        buildAboutPage(versionStaticLabel: aboutVersionStaticLabel)

        NSLayoutConstraint.activate([
            backgroundEffectView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundEffectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundEffectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundEffectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            rootStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            rootStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            rootStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rootStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            tabStripView.widthAnchor.constraint(lessThanOrEqualToConstant: 720),
            pageContainerView.widthAnchor.constraint(equalTo: rootStackView.widthAnchor),

            footerSeparatorView.widthAnchor.constraint(equalTo: rootStackView.widthAnchor),
            footerStackView.widthAnchor.constraint(equalTo: rootStackView.widthAnchor),

            basicPageView.topAnchor.constraint(equalTo: pageContainerView.topAnchor),
            basicPageView.leadingAnchor.constraint(equalTo: pageContainerView.leadingAnchor),
            basicPageView.trailingAnchor.constraint(equalTo: pageContainerView.trailingAnchor),
            basicPageView.bottomAnchor.constraint(lessThanOrEqualTo: pageContainerView.bottomAnchor),

            appearancePageView.topAnchor.constraint(equalTo: pageContainerView.topAnchor),
            appearancePageView.leadingAnchor.constraint(equalTo: pageContainerView.leadingAnchor),
            appearancePageView.trailingAnchor.constraint(equalTo: pageContainerView.trailingAnchor),
            appearancePageView.bottomAnchor.constraint(lessThanOrEqualTo: pageContainerView.bottomAnchor),

            rulesPageView.topAnchor.constraint(equalTo: pageContainerView.topAnchor),
            rulesPageView.leadingAnchor.constraint(equalTo: pageContainerView.leadingAnchor),
            rulesPageView.trailingAnchor.constraint(equalTo: pageContainerView.trailingAnchor),
            rulesPageView.bottomAnchor.constraint(lessThanOrEqualTo: pageContainerView.bottomAnchor),

            advancedPageView.topAnchor.constraint(equalTo: pageContainerView.topAnchor),
            advancedPageView.leadingAnchor.constraint(equalTo: pageContainerView.leadingAnchor),
            advancedPageView.trailingAnchor.constraint(equalTo: pageContainerView.trailingAnchor),
            advancedPageView.bottomAnchor.constraint(lessThanOrEqualTo: pageContainerView.bottomAnchor),

            aboutPageView.topAnchor.constraint(equalTo: pageContainerView.topAnchor),
            aboutPageView.leadingAnchor.constraint(equalTo: pageContainerView.leadingAnchor),
            aboutPageView.trailingAnchor.constraint(equalTo: pageContainerView.trailingAnchor),
            aboutPageView.bottomAnchor.constraint(lessThanOrEqualTo: pageContainerView.bottomAnchor)
        ])

        pageContainerHeightConstraint = pageContainerView.heightAnchor.constraint(equalToConstant: 1)
        pageContainerHeightConstraint?.priority = .required
        pageContainerHeightConstraint?.isActive = true

        updateTabSelection()
        updateVisiblePage(animated: false, forceResize: true)
        updateDefaultBrowserNotice()
        updateAboutVersion()
        }
    }

    private func buildTabStrip() {
        tabStripView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tabButtons.removeAll()

        for tab in SettingsTab.allCases {
            let button = NSButton(title: tab.title, target: self, action: #selector(selectTab(_:)))
            button.tag = SettingsTab.allCases.firstIndex(of: tab) ?? 0
            button.identifier = NSUserInterfaceItemIdentifier(tab.rawValue)
            button.image = NSImage(systemSymbolName: tab.symbolName, accessibilityDescription: nil)
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = .imageAbove
            button.isBordered = false
            button.bezelStyle = .regularSquare
            button.translatesAutoresizingMaskIntoConstraints = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 18
            button.layer?.masksToBounds = true
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.widthAnchor.constraint(equalToConstant: 112).isActive = true
            button.heightAnchor.constraint(equalToConstant: 112).isActive = true
            tabButtons[tab] = button
            tabStripView.addArrangedSubview(button)
        }

        updateTabSelection()
    }

    private func buildBasicPage() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        basicPageContentStack = stack

        stack.addArrangedSubview(defaultBrowserNoticeView)
        stack.addArrangedSubview(formRow(label: defaultBrowserLabel, control: defaultBrowserPopup))
        stack.addArrangedSubview(formRow(label: chooserModifierLabel, control: modifierPopup))
        stack.addArrangedSubview(browserSummaryLabel)

        basicPageView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: basicPageView.topAnchor, constant: settingsPageTopPadding),
            stack.leadingAnchor.constraint(equalTo: basicPageView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: basicPageView.trailingAnchor, constant: -32),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: basicPageView.bottomAnchor, constant: -settingsPageVerticalPadding),

            // Notice banner fills full row width
            defaultBrowserNoticeView.widthAnchor.constraint(equalTo: basicPageView.widthAnchor, constant: -64),

            defaultBrowserNoticeIcon.widthAnchor.constraint(equalToConstant: 16),
            defaultBrowserNoticeIcon.heightAnchor.constraint(equalToConstant: 16),
            defaultBrowserNoticeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 104),

            // Make both popup buttons the same width so they align
            modifierPopup.widthAnchor.constraint(equalTo: defaultBrowserPopup.widthAnchor)
        ])
    }

    private func buildAppearancePage() {
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

    private func buildRulesPage(rulesScrollView: NSScrollView, ruleButtonStack: NSStackView) {
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

    private func buildAdvancedPage(advancedHintLabel: NSTextField, refreshButton: NSButton, detectButton: NSButton, revealButton: NSButton) {
        let inventoryTitle = NSTextField(labelWithString: "Browser inventory")
        inventoryTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        inventoryTitle.translatesAutoresizingMaskIntoConstraints = false

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

        let stack = NSStackView(views: [advancedHintLabel, inventoryTitle, inventoryButtons, configTitle, configButtons])
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
            stack.bottomAnchor.constraint(equalTo: advancedPageView.bottomAnchor, constant: -settingsPageVerticalPadding)
        ])
    }

    private func buildAboutPage(versionStaticLabel: NSTextField) {
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
            stack.trailingAnchor.constraint(lessThanOrEqualTo: aboutPageView.trailingAnchor, constant: -32),
            stack.bottomAnchor.constraint(equalTo: aboutPageView.bottomAnchor, constant: -settingsPageVerticalPadding)
        ])
    }

    private func updateVisiblePage(animated: Bool = true, forceResize: Bool = false) {
        let pages: [(SettingsTab, NSView)] = [
            (.basic, basicPageView),
            (.appearance, appearancePageView),
            (.rules, rulesPageView),
            (.advanced, advancedPageView),
            (.about, aboutPageView)
        ]

        for (tab, page) in pages {
            page.isHidden = tab != selectedTab
        }

        guard let pageContainerHeightConstraint else {
            return
        }

        let targetHeight = preferredPageHeight(for: selectedTab)
        let delta = targetHeight - pageContainerHeightConstraint.constant
        guard abs(delta) > 0.5 || forceResize else {
            return
        }

        pageContainerHeightConstraint.constant = targetHeight

        guard let window else {
            return
        }

        window.contentView?.layoutSubtreeIfNeeded()

        let topMargin: CGFloat = 16
        let bottomMargin: CGFloat = 16
        let verticalSpacing: CGFloat = 14
        let tabHeight = tabStripView.fittingSize.height
        let footerHeight = footerStackView.fittingSize.height
        let separatorHeight: CGFloat = 1
        let contentHeight = topMargin
            + tabHeight
            + verticalSpacing
            + targetHeight
            + verticalSpacing
            + separatorHeight
            + verticalSpacing
            + footerHeight
            + bottomMargin

        let currentFrame = window.frame
        let newContentSize = NSSize(width: currentFrame.width, height: contentHeight)
        window.setContentSize(newContentSize)
    }

    private func preferredPageHeight(for tab: SettingsTab) -> CGFloat {
        switch tab {
        case .basic:
            return 250
        case .appearance:
            return 220
        case .rules:
            return 424
        case .advanced:
            return 270
        case .about:
            return 305
        }
    }

    private func preferredRulesListHeight() -> CGFloat {
        let rows = max(configuration.routingRules.count, 1)
        let rowHeight = CGFloat(rulesTableView.rowHeight + rulesTableView.intercellSpacing.height)
        return min(max(CGFloat(rows) * rowHeight + 34, 112), 228)
    }

    private func updateTabSelection() {
        for tab in SettingsTab.allCases {
            guard let button = tabButtons[tab] else {
                continue
            }

            let isSelected = tab == selectedTab
            let icon = NSImage(systemSymbolName: tab.symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: isSelected ? 22 : 20, weight: isSelected ? .semibold : .regular))
            button.image = icon
            button.title = tab.title
            button.attributedTitle = NSAttributedString(
                string: tab.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: isSelected ? .semibold : .regular),
                    .foregroundColor: isSelected ? NSColor.systemBlue : NSColor.secondaryLabelColor
                ]
            )
            button.contentTintColor = isSelected ? .systemBlue : .secondaryLabelColor
            button.layer?.backgroundColor = isSelected ? NSColor.windowBackgroundColor.cgColor : NSColor.clear.cgColor
            button.layer?.borderWidth = isSelected ? 1 : 0
            button.layer?.borderColor = NSColor(calibratedWhite: 0.32, alpha: 1).withAlphaComponent(isSelected ? 0.78 : 0).cgColor
            button.layer?.shadowOpacity = 0
        }
    }

    private func updateAboutVersion() {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            aboutVersionLabel.stringValue = "v\(version) (\(build))"
        } else {
            aboutVersionLabel.stringValue = "v\(version)"
        }
    }

    @objc private func selectTab(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < SettingsTab.allCases.count else {
            return
        }

        let tab = SettingsTab.allCases[sender.tag]
        selectedTab = tab
        updateTabSelection()
        updateVisiblePage()
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/KhalilHsu/broswerSwitch") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openReleases() {
        if let url = URL(string: "https://github.com/KhalilHsu/broswerSwitch/releases") {
            NSWorkspace.shared.open(url)
        }
    }

    private func formRow(label: NSTextField, control: NSView) -> NSView {
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 160).isActive = true
        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return row
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
        updateDefaultBrowserNotice()
    }

    private func configureMosStylePreferences(in contentView: NSView) {
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
        window.minSize = NSSize(width: 620, height: 240)
        window.center()

        defaultBrowserNoticeView.wantsLayer = true
        defaultBrowserNoticeView.layer?.cornerRadius = 12
        defaultBrowserNoticeView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.12).cgColor
        defaultBrowserNoticeView.layer?.borderWidth = 1
        defaultBrowserNoticeView.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.18).cgColor
        defaultBrowserNoticeView.translatesAutoresizingMaskIntoConstraints = false

        defaultBrowserNoticeIcon.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        defaultBrowserNoticeIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        defaultBrowserNoticeIcon.contentTintColor = .systemBlue
        defaultBrowserNoticeIcon.translatesAutoresizingMaskIntoConstraints = false

        defaultBrowserNoticeLabel.font = .systemFont(ofSize: 13, weight: .regular)
        defaultBrowserNoticeLabel.textColor = .labelColor
        defaultBrowserNoticeLabel.lineBreakMode = .byTruncatingTail
        defaultBrowserNoticeLabel.maximumNumberOfLines = 1
        defaultBrowserNoticeLabel.translatesAutoresizingMaskIntoConstraints = false

        defaultBrowserNoticeButton.target = self
        defaultBrowserNoticeButton.action = #selector(requestSetAsDefaultBrowser)
        defaultBrowserNoticeButton.bezelStyle = .rounded
        defaultBrowserNoticeButton.translatesAutoresizingMaskIntoConstraints = false
        configureDefaultBrowserNoticeContent()

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

        browserSummaryLabel.textColor = .secondaryLabelColor
        browserSummaryLabel.font = .systemFont(ofSize: 12)
        browserSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        ruleSummaryLabel.textColor = .secondaryLabelColor
        ruleSummaryLabel.font = .systemFont(ofSize: 12)
        ruleSummaryLabel.translatesAutoresizingMaskIntoConstraints = false

        rulesTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")))
        rulesTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("match")))
        rulesTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("browser")))
        rulesTableView.tableColumns[0].title = "Rule"
        rulesTableView.tableColumns[0].width = 120
        rulesTableView.tableColumns[1].title = "Match"
        rulesTableView.tableColumns[1].width = 160
        rulesTableView.tableColumns[2].title = "Browser/Profile"
        rulesTableView.tableColumns[2].width = 170
        rulesTableView.delegate = self
        rulesTableView.dataSource = self
        rulesTableView.usesAlternatingRowBackgroundColors = true
        rulesTableView.allowsMultipleSelection = false
        rulesTableView.rowHeight = 28
        rulesTableView.intercellSpacing = NSSize(width: 8, height: 4)
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

        aboutLogoLabel.font = .systemFont(ofSize: 34, weight: .light)
        aboutLogoLabel.alignment = .center
        aboutLogoLabel.translatesAutoresizingMaskIntoConstraints = false

        aboutDescriptionLabel.font = .systemFont(ofSize: 14)
        aboutDescriptionLabel.textColor = .secondaryLabelColor
        aboutDescriptionLabel.alignment = .center
        aboutDescriptionLabel.lineBreakMode = .byWordWrapping
        aboutDescriptionLabel.maximumNumberOfLines = 2
        aboutDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        aboutVersionLabel.font = .systemFont(ofSize: 13, weight: .regular)
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
            revealButton: makeRevealButton()
        )
        buildAboutPage(versionStaticLabel: makeAboutVersionLabel())

        // Apply notice visibility BEFORE measuring preferredContentSize so the
        // hidden notice view is excluded from the height calculation.
        updateDefaultBrowserNotice()

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

    private func preferredContentSize(for tab: SettingsTab) -> NSSize {
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

    private func configureDefaultBrowserNoticeContent() {
        guard defaultBrowserNoticeView.subviews.isEmpty else {
            return
        }

        let noticeTextStack = NSStackView(views: [defaultBrowserNoticeLabel])
        noticeTextStack.orientation = .vertical
        noticeTextStack.alignment = .leading
        noticeTextStack.spacing = 2
        noticeTextStack.translatesAutoresizingMaskIntoConstraints = false

        let noticeStack = NSStackView(views: [defaultBrowserNoticeIcon, noticeTextStack, defaultBrowserNoticeButton])
        noticeStack.orientation = .horizontal
        noticeStack.alignment = .centerY
        noticeStack.spacing = 12
        noticeStack.translatesAutoresizingMaskIntoConstraints = false

        defaultBrowserNoticeView.addSubview(noticeStack)
        NSLayoutConstraint.activate([
            noticeStack.topAnchor.constraint(equalTo: defaultBrowserNoticeView.topAnchor, constant: 10),
            noticeStack.leadingAnchor.constraint(equalTo: defaultBrowserNoticeView.leadingAnchor, constant: 12),
            noticeStack.trailingAnchor.constraint(equalTo: defaultBrowserNoticeView.trailingAnchor, constant: -12),
            noticeStack.bottomAnchor.constraint(equalTo: defaultBrowserNoticeView.bottomAnchor, constant: -10)
        ])
    }

    private func addTab(title: String, symbolName: String, view: NSView, size: NSSize) {
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

    private func makeRulesScrollView() -> NSScrollView {
        let rulesScrollView = NSScrollView()
        rulesScrollView.hasVerticalScroller = true
        rulesScrollView.documentView = rulesTableView
        rulesScrollView.translatesAutoresizingMaskIntoConstraints = false
        return rulesScrollView
    }

    private func makeRuleButtonStack() -> NSStackView {
        let addRuleButton = makeButton("Add Rule", action: #selector(addRule))
        let updateRuleButton = makeButton("Update Selected", action: #selector(updateSelectedRule))
        let removeRuleButton = makeButton("Remove Selected", action: #selector(removeSelectedRule))
        addRuleButton.keyEquivalent = "\r"
        let ruleButtonStack = NSStackView(views: [addRuleButton, updateRuleButton, removeRuleButton])
        ruleButtonStack.orientation = .horizontal
        ruleButtonStack.spacing = 8
        ruleButtonStack.translatesAutoresizingMaskIntoConstraints = false
        return ruleButtonStack
    }

    private func makeAdvancedHintLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "Use this page for browser inventory and the config file.")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeRefreshButton() -> NSButton {
        makeButton("Refresh Browsers", action: #selector(refreshBrowsers))
    }

    private func makeDetectButton() -> NSButton {
        makeButton("Detect Profiles", action: #selector(detectProfiles))
    }

    private func makeRevealButton() -> NSButton {
        makeButton("Open Config", action: #selector(revealConfigFile))
    }

    private func makeAboutVersionLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "Version")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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

    private func updateDefaultBrowserNotice() {
        let isDefaultBrowser = (try? DefaultBrowserManager())?.isRoutingToSelf() ?? false
        defaultBrowserNoticeView.isHidden = isDefaultBrowser
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
        rulesScrollViewHeightConstraint?.constant = preferredRulesListHeight()
    }

    @objc private func revealConfigFile() {
        _ = RouterConfiguration.load()
        NSWorkspace.shared.activateFileViewerSelecting([RouterConfiguration.configURL])
    }

    @objc private func requestSetAsDefaultBrowser() {
        onRequestSetAsDefaultBrowser()
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
