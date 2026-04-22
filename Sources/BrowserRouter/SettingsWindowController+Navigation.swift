import AppKit

extension SettingsWindowController {
    func buildTabStrip() {
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

    func updateVisiblePage(animated: Bool = true, forceResize: Bool = false) {
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

    func preferredPageHeight(for tab: SettingsTab) -> CGFloat {
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

    func preferredRulesListHeight() -> CGFloat {
        let rows = max(configuration.routingRules.count, 1)
        let rowHeight = CGFloat(rulesTableView.rowHeight + rulesTableView.intercellSpacing.height)
        return min(max(CGFloat(rows) * rowHeight + 34, 112), 228)
    }

    func updateTabSelection() {
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

    func updateAboutVersion() {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            aboutVersionLabel.stringValue = "v\(version) (\(build))"
        } else {
            aboutVersionLabel.stringValue = "v\(version)"
        }
    }

    @objc func selectTab(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < SettingsTab.allCases.count else {
            return
        }

        let tab = SettingsTab.allCases[sender.tag]
        selectedTab = tab
        updateTabSelection()
        updateVisiblePage()
    }

    @objc func openGitHub() {
        if let url = URL(string: "https://github.com/KhalilHsu/broswerSwitch") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openReleases() {
        if let url = URL(string: "https://github.com/KhalilHsu/broswerSwitch/releases") {
            NSWorkspace.shared.open(url)
        }
    }
}
