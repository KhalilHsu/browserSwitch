import AppKit
import Foundation
import BrowserRouterCore

@MainActor
final class BrowserChooserWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let url: URL
    private let options: [BrowserOption]
    private var filteredOptions: [BrowserOption]
    private let defaultOptionID: String
    private let onOpenSettings: () -> Void
    private let onSelect: (BrowserOption) -> Void
    private let onClose: () -> Void

    private let searchField = ChooserSearchField()
    private let tableView = NSTableView()
    private let resultLabel = NSTextField(labelWithString: "")

    init(
        url: URL,
        options: [BrowserOption],
        defaultOptionID: String,
        onOpenSettings: @escaping () -> Void,
        onSelect: @escaping (BrowserOption) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.url = url
        self.options = options
        self.filteredOptions = options
        self.defaultOptionID = defaultOptionID
        self.onOpenSettings = onOpenSettings
        self.onSelect = onSelect
        self.onClose = onClose

        let window = ChooserWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 430),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
        buildUI()
        wireKeyboardHandlers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        guard let window else {
            return
        }

        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Open link with")
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let hostLabel = NSTextField(labelWithString: URLLogSummary(url: url).description)
        hostLabel.font = .systemFont(ofSize: 11)
        hostLabel.textColor = .secondaryLabelColor
        hostLabel.lineBreakMode = .byTruncatingMiddle
        hostLabel.translatesAutoresizingMaskIntoConstraints = false

        searchField.placeholderString = "Search browser or profile"
        searchField.sendsSearchStringImmediately = true
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 42
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.allowsEmptySelection = false
        tableView.target = self
        tableView.doubleAction = #selector(openSelectedOption)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("option"))
        column.width = 420
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        resultLabel.font = .systemFont(ofSize: 11)
        resultLabel.textColor = .secondaryLabelColor
        resultLabel.stringValue = "\(options.count) option(s)"
        resultLabel.translatesAutoresizingMaskIntoConstraints = false

        let settingsButton = NSButton(title: "Settings...", target: self, action: #selector(openSettings))
        settingsButton.bezelStyle = .rounded
        settingsButton.translatesAutoresizingMaskIntoConstraints = false

        let openButton = NSButton(title: "Open", target: self, action: #selector(openSelectedOption))
        openButton.bezelStyle = .rounded
        openButton.keyEquivalent = "\r"
        openButton.translatesAutoresizingMaskIntoConstraints = false

        let footerStack = NSStackView(views: [resultLabel, NSView(), settingsButton, openButton])
        footerStack.orientation = .horizontal
        footerStack.alignment = .centerY
        footerStack.spacing = 8
        footerStack.translatesAutoresizingMaskIntoConstraints = false

        let rootStack = NSStackView(views: [titleLabel, hostLabel, searchField, scrollView, footerStack])
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 8
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        window.contentView = visualEffectView
        visualEffectView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 14),
            rootStack.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 14),
            rootStack.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -14),
            rootStack.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -12),

            titleLabel.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            hostLabel.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            searchField.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 270),
            footerStack.widthAnchor.constraint(equalTo: rootStack.widthAnchor)
        ])

        reloadFilter()
    }

    private func wireKeyboardHandlers() {
        searchField.onMoveDown = { [weak self] in
            self?.moveSelection(delta: 1)
        }
        searchField.onMoveUp = { [weak self] in
            self?.moveSelection(delta: -1)
        }
        searchField.onSubmit = { [weak self] in
            self?.openSelectedOption()
        }
        searchField.onCancel = { [weak self] in
            self?.close()
        }
    }

    func showNearMouse() {
        guard let window else {
            return
        }

        let mouse = NSEvent.mouseLocation
        let screenFrame = screen(containing: mouse)?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? .zero

        let margin: CGFloat = 10
        let size = window.frame.size
        let origin = NSPoint(
            x: max(screenFrame.minX + margin, min(mouse.x + margin, screenFrame.maxX - size.width - margin)),
            y: max(screenFrame.minY + margin, min(mouse.y - size.height - margin, screenFrame.maxY - size.height - margin))
        )
        window.setFrameOrigin(origin)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(searchField)
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    @objc private func searchChanged() {
        reloadFilter()
    }

    private func reloadFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            filteredOptions = options
        } else {
            filteredOptions = options.filter { option in
                [
                    option.name,
                    option.appName,
                    option.bundleIdentifier,
                    option.profileDirectory
                ]
                .compactMap { $0?.lowercased() }
                .contains { $0.contains(query) }
            }
        }

        tableView.reloadData()
        if filteredOptions.isEmpty {
            resultLabel.stringValue = "No matching options"
        } else {
            resultLabel.stringValue = "\(filteredOptions.count) of \(options.count) option(s)"
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    private func moveSelection(delta: Int) {
        guard !filteredOptions.isEmpty else {
            return
        }

        let current = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        let next = max(0, min(filteredOptions.count - 1, current + delta))
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    @objc private func openSelectedOption() {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredOptions.count else {
            return
        }

        let option = filteredOptions[row]
        close()
        onSelect(option)
    }

    @objc private func openSettings() {
        close()
        onOpenSettings()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredOptions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredOptions.count else {
            return nil
        }

        let option = filteredOptions[row]
        let title = option.id == defaultOptionID ? "\(option.name)  Default" : option.name
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: option.id == defaultOptionID ? .semibold : .regular)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let detailText = [
            option.appName,
            option.profileDirectory
        ]
        .compactMap { $0 }
        .joined(separator: " - ")
        let detailLabel = NSTextField(labelWithString: detailText.isEmpty ? option.bundleIdentifier : detailText)
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false

        let view = NSTableCellView()
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

private final class ChooserWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }
}

private final class ChooserSearchField: NSSearchField {
    var onMoveDown: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36:
            onSubmit?()
        case 53:
            onCancel?()
        case 125:
            onMoveDown?()
        case 126:
            onMoveUp?()
        default:
            super.keyDown(with: event)
        }
    }
}
