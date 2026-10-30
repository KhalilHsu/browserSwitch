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
        autoRestoreCheckBox.state = configuration.autoRestoreDefaultBrowserOnQuit ? .on : .off
        defaultBrowserPopup.removeAllItems()
        ruleBrowserPopup.removeAllItems()

        let usedRuleOptionIDs = Set(configuration.routingRules.map(\.browserOptionID))
        for option in visibleBrowserOptions {
            if !option.isHidden || option.id == configuration.defaultOptionID {
                let title = option.isHidden ? L("%@ (Hidden)", option.name) : option.name
                defaultBrowserPopup.addItem(withTitle: title)
                defaultBrowserPopup.lastItem?.representedObject = option.id
            }
            
            if !option.isHidden || usedRuleOptionIDs.contains(option.id) {
                let title = option.isHidden ? L("%@ (Hidden)", option.name) : option.name
                ruleBrowserPopup.addItem(withTitle: title)
                ruleBrowserPopup.lastItem?.representedObject = option.id
            }
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
        populateSourceAppPopup()
        updateSummaryLabels()
        updateRuleTesterResult()
        updateRuleEditorState()
    }

    @objc func refreshBrowsers() {
        let result = BrowserInventory.refreshConfiguration(configuration)
        configuration = result.configuration
        reloadControls()
        updateProfileAccessNote()
        _ = persistConfiguration(statusMessage: result.statusMessage)
    }

    /// Shows a small note when every profile was found but macOS hid some profile names.
    func updateProfileAccessNote() {
        let scan = ChromiumProfileScanner.scan(existingOptions: configuration.browserOptions)
            + FirefoxProfileScanner.scan(existingOptions: configuration.browserOptions)
        let apps = scan.appsMissingProfileNames
        profileAccessNoteLabel.stringValue = apps.isEmpty
            ? ""
            : L("Some %@ profiles show their folder name because macOS protects browser data. Allow Full Disk Access for BrowserRouter to read profile names.", apps.joined(separator: ", "))
        profileAccessNoteLabel.superview?.isHidden = apps.isEmpty
    }

    @objc func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    func persistConfiguration(statusMessage: String = L("Saved automatically")) -> Bool {
        do {
            configuration.showsDockIcon = showDockIconCheckBox.state == .on
            configuration.showsStatusItem = showStatusItemCheckBox.state == .on
            configuration.autoRestoreDefaultBrowserOnQuit = autoRestoreCheckBox.state == .on
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
            autosaveStatusLabel.stringValue = L("Autosave failed")
            autosaveStatusLabel.textColor = .systemRed
            showMessage(L("Could Not Save"), "\(error)")
            return false
        }
    }

    func updateSummaryLabels() {
        let unavailableCount = configuration.browserOptions.count - visibleBrowserOptions.count
        let browserText = unavailableCount == 0
            ? L("%d browser/profile option(s) available", visibleBrowserOptions.count)
            : L("%d available, %d unavailable", visibleBrowserOptions.count, unavailableCount)
        browserSummaryLabel.stringValue = browserText

        let unresolvedRuleCount = configuration.routingRules.filter { rule in
            rule.isEnabled &&
            !visibleBrowserOptions.contains(where: { $0.id == rule.browserOptionID })
        }.count
        let disabledRuleCount = configuration.routingRules.filter { !$0.isEnabled }.count
        var ruleParts = [L("%d rule(s)", configuration.routingRules.count)]
        if disabledRuleCount > 0 {
            ruleParts.append(L("%d disabled", disabledRuleCount))
        }
        if unresolvedRuleCount > 0 {
            ruleParts.append(L("%d need attention", unresolvedRuleCount))
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
        _ = persistConfiguration(statusMessage: L("Default browser saved"))
    }

    @objc func languageChanged() {
        guard let rawValue = selectedRepresentedObject(languagePopup),
              let language = AppLanguage(rawValue: rawValue),
              language != AppLanguage.current
        else {
            return
        }

        AppLanguage.current = language
        // The window is rebuilt by its owner, so let this action finish first.
        DispatchQueue.main.async { [onLanguageChange] in
            onLanguageChange()
        }
    }

    @objc func modifierChanged() {
        let isCustom = selectedRepresentedObject(modifierPopup) == ChooserModifier.custom.rawValue
        shortcutRecorderButton.isHidden = !isCustom
        updateRuleTesterResult()
        _ = persistConfiguration(statusMessage: L("Chooser modifier saved"))
    }

    func shortcutRecorded(_ shortcut: RecordedShortcut) {
        configuration.customChooserFlags = shortcut.flags.rawValue
        configuration.customChooserKeyCode = shortcut.keyCode
        _ = persistConfiguration(statusMessage: L("Custom shortcut saved - %@", shortcut.displayString))
    }

    @objc func presentationChanged() {
        _ = persistConfiguration(statusMessage: L("Appearance saved"))
    }

    @objc func autoRestoreChanged() {
        _ = persistConfiguration(statusMessage: L("Auto-restore setting saved"))
    }

    @objc func toggleBrowserVisibility(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < configuration.browserOptions.count else {
            return
        }

        configuration.browserOptions[row].isHidden = sender.state == .off
        browsersTableView.reloadData()
        _ = persistConfiguration(statusMessage: configuration.browserOptions[row].isHidden ? L("Browser hidden") : L("Browser unhidden"))
        reloadControls()
    }

    @objc func ruleBrowserChanged() {
        updateRuleEditorSheetState()
    }

    @objc func ruleSourceAppChanged() {
        if selectedRepresentedObject(ruleSourceAppPopup) == chooseOtherSourceAppToken {
            chooseOtherSourceApp()
            return
        }

        lastSourceAppSelection = selectedRepresentedObject(ruleSourceAppPopup) ?? ""
        updateRuleEditorSheetState()
    }

    @objc func ruleMatchTypeChanged() {
        updateRuleMatchPlaceholder()
        updateRuleEditorSheetState()
    }

    /// Fills the source app menu: Any App, apps already used by rules, running apps, then a picker for any other app.
    func populateSourceAppPopup() {
        let previousSelection = selectedRepresentedObject(ruleSourceAppPopup)
        ruleSourceAppPopup.removeAllItems()

        // Empty represented object means no source app filter.
        ruleSourceAppPopup.addItem(withTitle: L("Any App"))
        ruleSourceAppPopup.lastItem?.representedObject = "" as String

        var seenBundleIDs: Set<String> = ["com.khalil.browserrouter"]

        let usedSourceApps = configuration.routingRules
            .compactMap(\.sourceAppBundleID)
            .filter { !$0.isEmpty }
        let usedItems = usedSourceApps.compactMap { bundleID -> (String, String)? in
            guard seenBundleIDs.insert(bundleID).inserted else { return nil }
            return (sourceAppDisplayName(for: bundleID), bundleID)
        }.sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
        appendSourceAppSection(usedItems)

        let runningItems = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (String, String)? in
                guard let bundleID = app.bundleIdentifier, seenBundleIDs.insert(bundleID).inserted else { return nil }
                return (app.localizedName ?? bundleID, bundleID)
            }
            .sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
        appendSourceAppSection(runningItems)

        ruleSourceAppPopup.menu?.addItem(.separator())
        ruleSourceAppPopup.addItem(withTitle: L("Choose Other App…"))
        ruleSourceAppPopup.lastItem?.representedObject = chooseOtherSourceAppToken

        if let previousSelection, !previousSelection.isEmpty, previousSelection != chooseOtherSourceAppToken {
            ruleSourceAppPopup.selectItem(withRepresentedObject: previousSelection)
        }
    }

    private func appendSourceAppSection(_ items: [(title: String, bundleID: String)]) {
        guard !items.isEmpty else { return }
        ruleSourceAppPopup.menu?.addItem(.separator())
        for item in items {
            ruleSourceAppPopup.addItem(withTitle: item.title)
            ruleSourceAppPopup.lastItem?.representedObject = item.bundleID
        }
    }

    func sourceAppDisplayName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return L("%@ (Not Installed)", bundleID)
        }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    /// Lets the user pick any app bundle and uses its bundle ID as the rule's source app.
    func chooseOtherSourceApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = L("Choose")
        panel.message = L("Choose the app that opens links for this rule.")

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self else { return }
            guard response == .OK,
                  let url = panel.url,
                  let bundleID = Bundle(url: url)?.bundleIdentifier
            else {
                self.ruleSourceAppPopup.selectItem(withRepresentedObject: self.lastSourceAppSelection)
                return
            }

            if self.ruleSourceAppPopup.indexOfItem(withRepresentedObject: bundleID) < 0 {
                let title = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
                let index = self.ruleSourceAppPopup.indexOfItem(withRepresentedObject: self.chooseOtherSourceAppToken)
                self.ruleSourceAppPopup.insertItem(withTitle: title, at: max(index - 1, 1))
                self.ruleSourceAppPopup.item(at: max(index - 1, 1))?.representedObject = bundleID
            }
            self.ruleSourceAppPopup.selectItem(withRepresentedObject: bundleID)
            self.lastSourceAppSelection = bundleID
            self.updateRuleEditorSheetState()
        }

        if let sheet = ruleEditorSheet, sheet.isVisible {
            panel.beginSheetModal(for: sheet, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    var chooseOtherSourceAppToken: String { "__choose-other-app__" }

    func showMessage(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L("OK"))
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
