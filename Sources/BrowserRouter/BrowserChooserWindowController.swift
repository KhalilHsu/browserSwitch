import AppKit
import Foundation
import BrowserRouterCore

@MainActor
final class BrowserChooserWindowController: NSWindowController, NSWindowDelegate {
    private let url: URL
    private let options: [BrowserOption]
    private let defaultOptionID: String
    private let onOpenSettings: () -> Void
    private let onSelect: (BrowserOption) -> Void
    private let onClose: () -> Void

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
        self.defaultOptionID = defaultOptionID
        self.onOpenSettings = onOpenSettings
        self.onSelect = onSelect
        self.onClose = onClose

        let windowHeight = min(640, max(320, CGFloat(options.count) * 44 + 140))
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: windowHeight),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Open Link"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        guard let contentView = window?.contentView else {
            return
        }

        let title = NSTextField(labelWithString: "Open this link with")
        title.font = .boldSystemFont(ofSize: 18)
        title.translatesAutoresizingMaskIntoConstraints = false

        let settingsButton = NSButton()
        settingsButton.bezelStyle = .texturedRounded
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.toolTip = "Open Settings"
        if let image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Open Settings") {
            image.isTemplate = true
            settingsButton.image = image
            settingsButton.imagePosition = .imageOnly
            settingsButton.contentTintColor = .labelColor
        } else {
            settingsButton.title = "Settings"
        }
        settingsButton.translatesAutoresizingMaskIntoConstraints = false

        let detail = NSTextField(labelWithString: displayURL)
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingMiddle
        detail.maximumNumberOfLines = 1
        detail.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (index, option) in options.enumerated() {
            let button = NSButton(title: buttonTitle(for: option, index: index), target: self, action: #selector(selectOption(_:)))
            button.bezelStyle = .rounded
            button.alignment = .left
            button.tag = index
            if index < 9 {
                button.keyEquivalent = "\(index + 1)"
            }
            stack.addArrangedSubview(button)
        }

        let hint = NSTextField(labelWithString: "Use number keys for the first nine choices. Press Esc to cancel.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(title)
        contentView.addSubview(settingsButton)
        contentView.addSubview(detail)
        contentView.addSubview(stack)
        contentView.addSubview(hint)
        contentView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(lessThanOrEqualTo: settingsButton.leadingAnchor, constant: -12),

            settingsButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            settingsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 32),

            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            stack.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: detail.trailingAnchor),

            hint.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 14),
            hint.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            hint.trailingAnchor.constraint(lessThanOrEqualTo: cancelButton.leadingAnchor, constant: -12),
            hint.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            cancelButton.centerYAnchor.constraint(equalTo: hint.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: title.trailingAnchor)
        ])
    }

    private var displayURL: String {
        if let host = url.host, !host.isEmpty {
            return host + url.path
        }

        return url.absoluteString
    }

    private func buttonTitle(for option: BrowserOption, index: Int) -> String {
        let shortcut = index < 9 ? "\(index + 1). " : ""
        let defaultMarker = option.id == defaultOptionID ? "  Default" : ""
        return "\(shortcut)\(option.name)\(defaultMarker)"
    }

    func showNearMouse() {
        guard let window else {
            return
        }

        let mouse = NSEvent.mouseLocation
        let frame = window.frame
        window.setFrameOrigin(NSPoint(x: mouse.x - frame.width / 2, y: mouse.y - 24))
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func selectOption(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < options.count else {
            return
        }

        let option = options[sender.tag]
        close()
        onSelect(option)
    }

    @objc private func cancel() {
        close()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
