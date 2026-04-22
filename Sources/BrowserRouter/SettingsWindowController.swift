import AppKit
import Foundation
import BrowserRouterCore

enum RuleMatchField: String, CaseIterable {
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

final class SettingsTabViewController: NSTabViewController {
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

let settingsToolbarHeight = CGFloat(76.0)
let settingsTabContentWidth = CGFloat(520.0)
let settingsPageVerticalPadding = CGFloat(24.0)
let settingsPageTopPadding = settingsToolbarHeight + settingsPageVerticalPadding

@MainActor
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    enum SettingsTab: String, CaseIterable {
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

    let showDockIconCheckBox = NSButton(checkboxWithTitle: "Show Dock icon", target: nil, action: nil)
    let showStatusItemCheckBox = NSButton(checkboxWithTitle: "Show menu bar icon", target: nil, action: nil)
    let defaultBrowserLabel = NSTextField(labelWithString: "Default browser/profile")
    let chooserModifierLabel = NSTextField(labelWithString: "Show chooser when")
    let defaultBrowserPopup = NSPopUpButton()
    let modifierPopup = NSPopUpButton()
    let rulesTableView = NSTableView()
    let ruleNameField = NSTextField()
    let ruleMatchTypePopup = NSPopUpButton()
    let ruleMatchValueField = NSTextField()
    let ruleBrowserPopup = NSPopUpButton()
    let autosaveStatusLabel = NSTextField(labelWithString: "Changes save automatically")
    let browserSummaryLabel = NSTextField(labelWithString: "")
    let ruleSummaryLabel = NSTextField(labelWithString: "")
    let headerTitleLabel = NSTextField(labelWithString: "BrowserRouter")
    let headerSubtitleLabel = NSTextField(labelWithString: "Route external links to the browser or profile that fits the moment.")
    let tabStripView = NSStackView()
    let rootStackView = NSStackView()
    let backgroundEffectView = NSVisualEffectView()
    let pageContainerView = NSView()
    let footerSeparatorView = NSBox()
    let footerStackView = NSStackView()
    let basicPageView = NSView()
    let appearancePageView = NSView()
    let rulesPageView = NSView()
    let advancedPageView = NSView()
    let aboutPageView = NSView()
    let aboutLogoLabel = NSTextField(labelWithString: "BrowserRouter")
    let aboutDescriptionLabel = NSTextField(labelWithString: "Regrettably, I have only made some minor contributions to the open-source community.")
    let aboutVersionLabel = NSTextField(labelWithString: "")
    let aboutGitHubButton = NSButton(title: "GitHub", target: nil, action: nil)
    let aboutWebsiteButton = NSButton(title: "Project", target: nil, action: nil)
    let settingsTabViewController = SettingsTabViewController()
    var configuration: RouterConfiguration
    var visibleBrowserOptions: [BrowserOption] = []
    var isPopulatingRuleForm = false
    var selectedTab: SettingsTab = .basic
    var tabButtons: [SettingsTab: NSButton] = [:]
    var pageContainerHeightConstraint: NSLayoutConstraint?
    var rulesScrollViewHeightConstraint: NSLayoutConstraint?
    var basicPageContentStack: NSStackView?
    var appearancePageContentStack: NSStackView?
    var rulesPageContentStack: NSStackView?
    var advancedPageContentStack: NSStackView?
    var aboutPageContentStack: NSStackView?
    let onSave: (RouterConfiguration) -> Void

    init(
        configuration: RouterConfiguration,
        onSave: @escaping (RouterConfiguration) -> Void
    ) {
        self.configuration = configuration
        self.onSave = onSave

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
    }
}
