import AppKit
import Foundation
import BrowserRouterCore

@MainActor
final class BrowserChooserWindowController: NSWindowController, NSWindowDelegate, NSMenuDelegate {
    private let url: URL
    private let options: [BrowserOption]
    private let defaultOptionID: String
    private let onOpenSettings: () -> Void
    private let onSelect: (BrowserOption) -> Void
    private let onClose: () -> Void

    private let hostView = MenuHostView(frame: .zero)
    private lazy var popupMenu = buildMenu()

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

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .popUpMenu
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = hostView

        super.init(window: window)
        window.delegate = self
        hostView.popupMenu = popupMenu
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "Open Link")
        menu.delegate = self
        menu.autoenablesItems = false

        let header = NSMenuItem(title: "Open this link with", action: nil, keyEquivalent: "")
        header.isEnabled = false
        header.attributedTitle = NSAttributedString(
            string: "Open this link with",
            attributes: [
                .font: NSFont.menuFont(ofSize: 13),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(header)

        menu.addItem(.separator())

        for (index, option) in options.enumerated() {
            let item = NSMenuItem(
                title: option.name,
                action: #selector(selectOption(_:)),
                keyEquivalent: index < 9 ? "\(index + 1)" : ""
            )
            item.target = self
            item.tag = index
            item.keyEquivalentModifierMask = []
            item.state = option.id == defaultOptionID ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)

        return menu
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
        let origin = NSPoint(
            x: max(screenFrame.minX + margin, min(mouse.x + margin, screenFrame.maxX - margin)),
            y: max(screenFrame.minY + margin, min(mouse.y - margin, screenFrame.maxY - margin))
        )
        window.setFrameOrigin(origin)
        window.orderFrontRegardless()

        DispatchQueue.main.async { [weak self] in
            self?.hostView.showMenu()
        }
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    @objc private func selectOption(_ sender: NSMenuItem) {
        guard sender.tag >= 0, sender.tag < options.count else {
            return
        }

        let option = options[sender.tag]
        close()
        onSelect(option)
    }

    @objc private func openSettings() {
        close()
        onOpenSettings()
    }

    func menuDidClose(_ menu: NSMenu) {
        close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

private final class MenuHostView: NSView {
    weak var popupMenu: NSMenu?
    private var didShowMenu = false

    func showMenu() {
        guard !didShowMenu, let popupMenu else {
            return
        }

        didShowMenu = true
        popupMenu.popUp(positioning: nil as NSMenuItem?, at: NSPoint(x: 0, y: 0), in: self)
    }
}
