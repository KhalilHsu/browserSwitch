import AppKit
import BrowserRouterCore

extension SettingsWindowController {
    func reload(with configuration: RouterConfiguration) {
        self.configuration = configuration
        reloadControls()
    }

    func reloadControls() {
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

    @objc func detectProfiles() {
        configuration = ChromiumProfileScanner.mergeDetectedOptions(into: configuration)
        reloadControls()
        _ = persistConfiguration(statusMessage: "Profiles detected and saved")
    }

    @objc func refreshBrowsers() {
        let result = BrowserInventory.refreshConfiguration(configuration)
        configuration = result.configuration
        reloadControls()
        _ = persistConfiguration(statusMessage: result.statusMessage)
    }

    func persistConfiguration(statusMessage: String = "Saved automatically") -> Bool {
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

    func updateSummaryLabels() {
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

    @objc func revealConfigFile() {
        _ = RouterConfiguration.load()
        NSWorkspace.shared.activateFileViewerSelecting([RouterConfiguration.configURL])
    }

    @objc func closeWindow() {
        window?.close()
    }

    @objc func defaultBrowserChanged() {
        _ = persistConfiguration(statusMessage: "Default browser saved")
    }

    @objc func modifierChanged() {
        _ = persistConfiguration(statusMessage: "Chooser modifier saved")
    }

    @objc func presentationChanged() {
        _ = persistConfiguration(statusMessage: "Appearance saved")
    }

    @objc func ruleBrowserChanged() {
        _ = autosaveSelectedRuleIfPossible(statusMessage: "Selected rule updated automatically")
    }

    @objc func ruleMatchTypeChanged() {
        updateRuleMatchPlaceholder()
        _ = autosaveSelectedRuleIfPossible(statusMessage: "Selected rule updated automatically")
    }

    func showMessage(_ title: String, _ message: String) {
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

    func selectedRepresentedObject(_ popup: NSPopUpButton) -> String? {
        popup.selectedItem?.representedObject as? String
    }
}
