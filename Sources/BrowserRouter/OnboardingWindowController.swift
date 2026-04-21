import AppKit
import Foundation
import BrowserRouterCore

private let onboardingContentWidth = CGFloat(520.0)
private let onboardingHorizontalPadding = CGFloat(40.0)
private let onboardingTextWidth = onboardingContentWidth - (onboardingHorizontalPadding * 2)
private let onboardingTakeoverHeight = CGFloat(244.0)
private let onboardingSelectionHeight = CGFloat(286.0)
private let onboardingFinishHeight = CGFloat(270.0)

@MainActor
final class OnboardingWindowController: NSWindowController {
    private enum Step {
        case takeover
        case chooseDefault
        case chooseModifier
        case finish
    }

    private let stepLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(labelWithString: "")
    private let defaultBrowserPopup = NSPopUpButton()
    private let modifierPopup = NSPopUpButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private let primaryButton = NSButton(title: "", target: nil, action: nil)
    private let onRequestSetAsDefaultBrowser: (@escaping (Bool, RouterConfiguration) -> Void) -> Void
    private let onComplete: (RouterConfiguration) -> Void

    private var configuration: RouterConfiguration
    private var visibleBrowserOptions: [BrowserOption] = []
    private var step: Step

    init(
        configuration: RouterConfiguration,
        isRoutingToSelf: Bool,
        onRequestSetAsDefaultBrowser: @escaping (@escaping (Bool, RouterConfiguration) -> Void) -> Void,
        onComplete: @escaping (RouterConfiguration) -> Void
    ) {
        self.configuration = BrowserInventory.refreshConfiguration(configuration).configuration
        self.step = isRoutingToSelf ? .chooseDefault : .takeover
        self.onRequestSetAsDefaultBrowser = onRequestSetAsDefaultBrowser
        self.onComplete = onComplete

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: onboardingContentWidth, height: onboardingTakeoverHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Set Up BrowserRouter"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .preference
            window.titlebarSeparatorStyle = .none
        }
        window.center()
        window.minSize = NSSize(width: onboardingContentWidth, height: onboardingTakeoverHeight)
        window.maxSize = NSSize(width: onboardingContentWidth, height: .greatestFiniteMagnitude)

        super.init(window: window)
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

        let backgroundView = NSVisualEffectView()
        backgroundView.material = .toolTip
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .followsWindowActiveState
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backgroundView)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = .clear

        stepLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        stepLabel.textColor = .systemBlue
        stepLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.maximumNumberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.preferredMaxLayoutWidth = onboardingTextWidth
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.maximumNumberOfLines = 0
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.preferredMaxLayoutWidth = onboardingTextWidth
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        defaultBrowserPopup.translatesAutoresizingMaskIntoConstraints = false
        defaultBrowserPopup.target = self
        defaultBrowserPopup.action = #selector(defaultBrowserChanged)

        modifierPopup.translatesAutoresizingMaskIntoConstraints = false
        modifierPopup.target = self
        modifierPopup.action = #selector(modifierChanged)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 0
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.preferredMaxLayoutWidth = onboardingTextWidth
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        primaryButton.target = self
        primaryButton.bezelStyle = .rounded
        primaryButton.keyEquivalent = "\r"
        primaryButton.controlSize = .regular
        primaryButton.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = NSStackView(views: [
            stepLabel,
            titleLabel,
            bodyLabel,
            defaultBrowserPopup,
            modifierPopup,
            statusLabel
        ])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let footerStack = NSStackView(views: [primaryButton])
        footerStack.orientation = .horizontal
        footerStack.alignment = .centerY
        footerStack.distribution = .gravityAreas
        footerStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(contentStack)
        contentView.addSubview(footerStack)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 54),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: onboardingHorizontalPadding),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -onboardingHorizontalPadding),

            titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: onboardingTextWidth),
            bodyLabel.widthAnchor.constraint(equalToConstant: onboardingTextWidth),
            statusLabel.widthAnchor.constraint(equalToConstant: onboardingTextWidth),

            defaultBrowserPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            modifierPopup.widthAnchor.constraint(equalTo: defaultBrowserPopup.widthAnchor),

            footerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: onboardingHorizontalPadding),
            footerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -onboardingHorizontalPadding),
            footerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            footerStack.topAnchor.constraint(greaterThanOrEqualTo: contentStack.bottomAnchor, constant: 14),

            primaryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 154)
        ])
    }

    func reload(with configuration: RouterConfiguration, isRoutingToSelf: Bool) {
        self.configuration = BrowserInventory.refreshConfiguration(configuration).configuration
        if isRoutingToSelf, step == .takeover {
            step = .chooseDefault
        }
        reloadControls()
    }

    private func reloadControls() {
        visibleBrowserOptions = BrowserAvailability.installedOptions(from: configuration.browserOptions)
        defaultBrowserPopup.removeAllItems()

        for option in visibleBrowserOptions {
            defaultBrowserPopup.addItem(withTitle: option.name)
            defaultBrowserPopup.lastItem?.representedObject = option.id
        }

        modifierPopup.removeAllItems()
        for modifier in ChooserModifier.allCases {
            modifierPopup.addItem(withTitle: modifier.title)
            modifierPopup.lastItem?.representedObject = modifier.rawValue
        }
        modifierPopup.selectItem(withRepresentedObject: configuration.chooserModifier)

        let resolvedDefaultID = visibleBrowserOptions.contains(where: { $0.id == configuration.defaultOptionID })
            ? configuration.defaultOptionID
            : visibleBrowserOptions.first?.id
        if let resolvedDefaultID {
            configuration.defaultOptionID = resolvedDefaultID
            defaultBrowserPopup.selectItem(withRepresentedObject: resolvedDefaultID)
        }

        switch step {
        case .takeover:
            stepLabel.stringValue = "Step 1 of 4"
            titleLabel.stringValue = "Make BrowserRouter default"
            bodyLabel.stringValue = "Set BrowserRouter as the macOS default so it can route links to the browser or profile you choose."
            defaultBrowserPopup.isHidden = true
            modifierPopup.isHidden = true
            statusLabel.isHidden = statusLabel.stringValue.isEmpty
            primaryButton.title = "Set as Default"
            primaryButton.action = #selector(requestSetAsDefaultBrowser)
            primaryButton.isEnabled = true
        case .chooseDefault:
            stepLabel.stringValue = "Step 2 of 4"
            titleLabel.stringValue = "Choose your default route"
            bodyLabel.stringValue = "When no rule matches, links open here."
            defaultBrowserPopup.isHidden = false
            modifierPopup.isHidden = true
            statusLabel.isHidden = false
            primaryButton.title = "Continue"
            primaryButton.action = #selector(continueToModifier)
            primaryButton.isEnabled = !visibleBrowserOptions.isEmpty
            statusLabel.stringValue = visibleBrowserOptions.isEmpty
                ? "No installed browsers were detected from the current configuration."
                : "Default route: \(defaultBrowserPopup.titleOfSelectedItem ?? "Choose a browser")"
        case .chooseModifier:
            stepLabel.stringValue = "Step 3 of 4"
            titleLabel.stringValue = "Choose your chooser shortcut"
            bodyLabel.stringValue = "Hold this shortcut while opening a link to pick a browser/profile instead of using the default route."
            defaultBrowserPopup.isHidden = true
            modifierPopup.isHidden = false
            statusLabel.isHidden = false
            primaryButton.title = "Continue"
            primaryButton.action = #selector(continueToFinish)
            primaryButton.isEnabled = true
            statusLabel.stringValue = "Shortcut: \(modifierPopup.titleOfSelectedItem ?? ChooserModifier.commandShift.title)"
        case .finish:
            stepLabel.stringValue = "Step 4 of 4"
            titleLabel.stringValue = "You're ready to route links"
            bodyLabel.stringValue = "Use Settings later to add site rules, refresh browser profiles, or change menu bar options."
            defaultBrowserPopup.isHidden = true
            modifierPopup.isHidden = true
            statusLabel.isHidden = false
            primaryButton.title = "Finish"
            primaryButton.action = #selector(finishSetup)
            primaryButton.isEnabled = true
            statusLabel.stringValue = "Rules live in Settings > Rules."
        }
        resizeWindowForCurrentStep()
    }

    @objc private func requestSetAsDefaultBrowser() {
        primaryButton.isEnabled = false
        statusLabel.isHidden = false
        statusLabel.stringValue = "Waiting for macOS to update the default browser..."

        onRequestSetAsDefaultBrowser { [weak self] success, configuration in
            guard let self else {
                return
            }

            self.configuration = BrowserInventory.refreshConfiguration(configuration).configuration
            if success {
                self.step = .chooseDefault
                self.statusLabel.stringValue = ""
                self.statusLabel.isHidden = true
            } else {
                self.statusLabel.isHidden = false
                self.statusLabel.stringValue = "BrowserRouter was not set as the default browser. Try again from this step."
            }
            self.reloadControls()
        }
    }

    @objc private func continueToModifier() {
        guard let selectedID = selectedRepresentedObject(defaultBrowserPopup) else {
            statusLabel.isHidden = false
            statusLabel.stringValue = "Choose a browser/profile before continuing."
            return
        }

        configuration.defaultOptionID = selectedID
        statusLabel.stringValue = ""
        statusLabel.isHidden = true
        step = .chooseModifier
        reloadControls()
    }

    @objc private func continueToFinish() {
        configuration.chooserModifier = selectedRepresentedObject(modifierPopup)
            ?? ChooserModifier.commandShift.rawValue
        statusLabel.stringValue = ""
        statusLabel.isHidden = true
        step = .finish
        reloadControls()
    }

    @objc private func finishSetup() {
        configuration.hasCompletedOnboarding = true

        do {
            try configuration.save()
            onComplete(configuration)
            close()
        } catch {
            statusLabel.isHidden = false
            statusLabel.stringValue = "Could not save setup: \(error.localizedDescription)"
        }
    }

    @objc private func defaultBrowserChanged() {
        statusLabel.isHidden = false
        statusLabel.stringValue = "Default route: \(defaultBrowserPopup.titleOfSelectedItem ?? "Choose a browser")"
    }

    @objc private func modifierChanged() {
        configuration.chooserModifier = selectedRepresentedObject(modifierPopup)
            ?? ChooserModifier.commandShift.rawValue
        statusLabel.isHidden = false
        statusLabel.stringValue = "Shortcut: \(modifierPopup.titleOfSelectedItem ?? ChooserModifier.commandShift.title)"
    }

    private func selectedRepresentedObject(_ popup: NSPopUpButton) -> String? {
        popup.selectedItem?.representedObject as? String
    }

    private func resizeWindowForCurrentStep() {
        guard let window else {
            return
        }

        let targetHeight: CGFloat
        switch step {
        case .takeover:
            targetHeight = onboardingTakeoverHeight
        case .chooseDefault, .chooseModifier:
            targetHeight = onboardingSelectionHeight
        case .finish:
            targetHeight = onboardingFinishHeight
        }
        let currentFrame = window.frame
        guard abs(currentFrame.height - targetHeight) > 1 else {
            return
        }

        let newFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - targetHeight,
            width: currentFrame.width,
            height: targetHeight
        )
        window.setFrame(newFrame, display: true, animate: false)
    }
}
