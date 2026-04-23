import AppKit
import CoreGraphics

// MARK: - Data

/// A recorded shortcut combination (modifier flags + optional letter key).
struct RecordedShortcut {
    let flags: CGEventFlags
    let keyCode: Int?       // nil = modifier-only combo
    let displayString: String

    static func make(flags: CGEventFlags, keyCode: Int?, characters: String?) -> RecordedShortcut {
        var parts: [String] = []
        if flags.contains(.maskControl)   { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift)     { parts.append("⇧") }
        if flags.contains(.maskCommand)   { parts.append("⌘") }
        if let kc = keyCode {
            // Prefer a special-key symbol; fall back to the raw character
            let keyStr = keyCodeDisplayName(kc) ?? characters?.uppercased() ?? "#\(kc)"
            parts.append(keyStr)
        }
        let display = parts.isEmpty ? "–" : parts.joined()
        return RecordedShortcut(flags: flags, keyCode: keyCode, displayString: display)
    }

    /// Human-readable name for a virtual key code.
    static func keyCodeDisplayName(_ keyCode: Int) -> String? {
        switch keyCode {
        // Letters (A-Z)
        case 0: return "A"; case 1: return "S"; case 2: return "D"; case 3: return "F"
        case 4: return "H"; case 5: return "G"; case 6: return "Z"; case 7: return "X"
        case 8: return "C"; case 9: return "V"; case 11: return "B"; case 12: return "Q"
        case 13: return "W"; case 14: return "E"; case 15: return "R"; case 16: return "Y"
        case 17: return "T"; case 31: return "O"; case 32: return "U"; case 34: return "I"
        case 35: return "P"; case 37: return "L"; case 38: return "J"; case 40: return "K"
        case 41: return ";"; case 45: return "N"; case 46: return "M"
        // Numbers
        case 18: return "1"; case 19: return "2"; case 20: return "3"; case 21: return "4"
        case 22: return "6"; case 23: return "5"; case 25: return "9"; case 26: return "7"
        case 28: return "8"; case 29: return "0"
        // Function keys
        case 122: return "F1"; case 120: return "F2"; case 99: return "F3"; case 118: return "F4"
        case 96: return "F5"; case 97: return "F6"; case 98: return "F7"; case 100: return "F8"
        case 101: return "F9"; case 109: return "F10"; case 103: return "F11"; case 111: return "F12"
        // Special keys
        case 36: return "↩"; case 76: return "⌅"   // Return, Enter
        case 48: return "⇥"; case 49: return "Space" // Tab, Space
        case 51: return "⌫"; case 117: return "⌦"   // Delete, Forward Delete
        case 53: return "⎋"                           // Escape
        case 123: return "←"; case 124: return "→"; case 125: return "↓"; case 126: return "↑"
        case 116: return "⇞"; case 121: return "⇟"   // Page Up, Page Down
        case 115: return "↖"; case 119: return "↘"   // Home, End
        default: return nil
        }
    }
}

// MARK: - ShortcutRecorderButton

/// A button that opens a popover for recording a modifier-key (+ optional letter) shortcut.
final class ShortcutRecorderButton: NSButton {

    var onRecorded: ((RecordedShortcut) -> Void)?

    var recordedShortcut: RecordedShortcut? {
        didSet { title = recordedShortcut?.displayString ?? "Click to record" }
    }

    private var popover: NSPopover?

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        bezelStyle = .rounded
        translatesAutoresizingMaskIntoConstraints = false
        title = "Click to record"
        target = self
        action = #selector(openPopover)
    }

    @objc private func openPopover() {
        if let p = popover, p.isShown { p.close(); popover = nil; return }

        let vc = ShortcutCaptureViewController()
        vc.onSave = { [weak self] shortcut in
            self?.recordedShortcut = shortcut
            self?.onRecorded?(shortcut)
            self?.popover?.close()
            self?.popover = nil
        }
        vc.onCancel = { [weak self] in
            self?.popover?.close()
            self?.popover = nil
        }

        let p = NSPopover()
        p.contentViewController = vc
        p.behavior = .semitransient
        p.show(relativeTo: bounds, of: self, preferredEdge: .maxY)
        popover = p
    }
}

// MARK: - Capture View (receives keyboard events inside the popover)

final class ShortcutCaptureView: NSView {
    var onKey: ((CGEventFlags, Int?, String?) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let kc = Int(event.keyCode)
        guard kc != 53 else { super.keyDown(with: event); return } // Esc → cancel
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).asCGFlags
        let chars = event.charactersIgnoringModifiers
        // Forward ALL key presses (with or without modifiers) to the capture handler.
        onKey?(flags, kc, chars)
    }

    override func flagsChanged(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).asCGFlags
        onKey?(flags, nil, nil)
    }
}

// MARK: - Capture View Controller

final class ShortcutCaptureViewController: NSViewController {

    var onSave: ((RecordedShortcut) -> Void)?
    var onCancel: (() -> Void)?

    private let captureView = ShortcutCaptureView()
    private let displayLabel = NSTextField(labelWithString: "–")
    private let hintLabel    = NSTextField(labelWithString: "Press modifier keys, optionally add a letter/number key")
    private let saveButton   = NSButton(title: "Save", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)

    private var pendingShortcut: RecordedShortcut?

    override func loadView() {
        captureView.frame = NSRect(x: 0, y: 0, width: 300, height: 168)
        view = captureView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Display label (large shortcut preview)
        displayLabel.font = .systemFont(ofSize: 32, weight: .light)
        displayLabel.alignment = .center
        displayLabel.textColor = .tertiaryLabelColor
        displayLabel.translatesAutoresizingMaskIntoConstraints = false

        // Hint
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .center
        hintLabel.lineBreakMode = .byWordWrapping
        hintLabel.maximumNumberOfLines = 2
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let titleLabel = NSTextField(labelWithString: "Record Shortcut")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Buttons
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(save)
        saveButton.isEnabled = false
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonRow = NSStackView(views: [cancelButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        captureView.addSubview(titleLabel)
        captureView.addSubview(displayLabel)
        captureView.addSubview(hintLabel)
        captureView.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: captureView.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: captureView.centerXAnchor),

            displayLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            displayLabel.leadingAnchor.constraint(equalTo: captureView.leadingAnchor, constant: 16),
            displayLabel.trailingAnchor.constraint(equalTo: captureView.trailingAnchor, constant: -16),

            hintLabel.topAnchor.constraint(equalTo: displayLabel.bottomAnchor, constant: 6),
            hintLabel.leadingAnchor.constraint(equalTo: captureView.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: captureView.trailingAnchor, constant: -16),

            buttonRow.bottomAnchor.constraint(equalTo: captureView.bottomAnchor, constant: -14),
            buttonRow.trailingAnchor.constraint(equalTo: captureView.trailingAnchor, constant: -16)
        ])

        // Wire up key capture
        captureView.onKey = { [weak self] flags, keyCode, chars in
            self?.handleKeyInput(flags: flags, keyCode: keyCode, characters: chars)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(captureView)
    }

    private func handleKeyInput(flags: CGEventFlags, keyCode: Int?, characters: String?) {
        if let keyCode {
            // A concrete key was pressed — always record it (with or without modifiers)
            let shortcut = RecordedShortcut.make(flags: flags, keyCode: keyCode, characters: characters)
            pendingShortcut = shortcut
            displayLabel.stringValue = shortcut.displayString
            displayLabel.textColor = .labelColor
            saveButton.isEnabled = true
        } else {
            // Pure modifier-key change (no letter/special key yet)
            let hasMod = flags.hasModifier
            if hasMod {
                let shortcut = RecordedShortcut.make(flags: flags, keyCode: nil, characters: nil)
                pendingShortcut = shortcut
                displayLabel.stringValue = shortcut.displayString
                displayLabel.textColor = .labelColor
                saveButton.isEnabled = true
            } else {
                // All modifiers released with nothing else recorded — clear
                if pendingShortcut?.keyCode == nil {
                    pendingShortcut = nil
                    displayLabel.stringValue = "–"
                    displayLabel.textColor = .tertiaryLabelColor
                    saveButton.isEnabled = false
                }
                // If a key+modifier combo was already recorded, keep displaying it
            }
        }
    }

    @objc private func save() {
        guard let s = pendingShortcut else { return }
        onSave?(s)
    }

    @objc private func cancel() {
        onCancel?()
    }
}

// MARK: - Private helpers

private extension NSEvent.ModifierFlags {
    var asCGFlags: CGEventFlags {
        var f = CGEventFlags()
        if contains(.control) { f.insert(.maskControl) }
        if contains(.option)  { f.insert(.maskAlternate) }
        if contains(.shift)   { f.insert(.maskShift) }
        if contains(.command) { f.insert(.maskCommand) }
        return f
    }
}

private extension CGEventFlags {
    var hasModifier: Bool {
        !intersection([.maskControl, .maskAlternate, .maskShift, .maskCommand]).isEmpty
    }
}
