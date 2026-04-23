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

        let isCustom = configuration.chooserModifier == ChooserModifier.custom.rawValue
        shortcutRecorderButton.isHidden = !isCustom
        if isCustom, let rawFlags = configuration.customChooserFlags {
            let flags = CGEventFlags(rawValue: rawFlags)
            let keyCode = configuration.customChooserKeyCode
            let shortcut = RecordedShortcut.make(flags: flags, keyCode: keyCode, characters: nil)
            shortcutRecorderButton.recordedShortcut = shortcut
        }

        rulesTableView.reloadData()
        updateSummaryLabels()
        updateRuleTesterResult()
        if !configuration.routingRules.isEmpty {
            rulesTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            populateRuleForm(from: configuration.routingRules[0])
        } else {
            clearRuleForm()
        }
    }

    @objc func detectProfiles() {
        configuration = ChromiumProfileScanner.mergeDetectedOptions(into: configuration)
        configuration = FirefoxProfileScanner.mergeDetectedOptions(into: configuration)
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
            rule.isEnabled &&
            !visibleBrowserOptions.contains(where: { $0.id == rule.browserOptionID })
        }.count
        let disabledRuleCount = configuration.routingRules.filter { !$0.isEnabled }.count
        var ruleParts = ["\(configuration.routingRules.count) rule(s)"]
        if disabledRuleCount > 0 {
            ruleParts.append("\(disabledRuleCount) disabled")
        }
        if unresolvedRuleCount > 0 {
            ruleParts.append("\(unresolvedRuleCount) need attention")
        }
        ruleSummaryLabel.stringValue = ruleParts.joined(separator: ", ")
        ruleSummaryLabel.textColor = unresolvedRuleCount == 0 ? .secondaryLabelColor : .systemOrange
        rulesScrollViewHeightConstraint?.constant = preferredRulesListHeight()
    }

    @objc func revealConfigFile() {
        _ = RouterConfiguration.load()
        NSWorkspace.shared.activateFileViewerSelecting([RouterConfiguration.configURL])
    }

    @objc func restorePreviousDefaultBrowser() {
        onRestoreDefaultBrowser()
    }

    @objc func closeWindow() {
        window?.close()
    }

    @objc func defaultBrowserChanged() {
        updateRuleTesterResult()
        _ = persistConfiguration(statusMessage: "Default browser saved")
    }

    @objc func modifierChanged() {
        let isCustom = selectedRepresentedObject(modifierPopup) == ChooserModifier.custom.rawValue
        shortcutRecorderButton.isHidden = !isCustom
        updateRuleTesterResult()
        _ = persistConfiguration(statusMessage: "Chooser modifier saved")
    }

    func shortcutRecorded(_ shortcut: RecordedShortcut) {
        configuration.customChooserFlags = shortcut.flags.rawValue
        configuration.customChooserKeyCode = shortcut.keyCode
        _ = persistConfiguration(statusMessage: "Custom shortcut saved – \(shortcut.displayString)")
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
