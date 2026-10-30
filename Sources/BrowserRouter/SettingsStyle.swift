import AppKit

/// Shared type scale for the settings window, so every page uses the same three text styles:
/// section titles (13 semibold), body text (13 regular, the AppKit default) and hints (11 secondary).
enum SettingsStyle {
    static let sectionTitleFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let hintFont = NSFont.systemFont(ofSize: 11)
    static let contentWidth = settingsTabContentWidth - 64

    static func sectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = sectionTitleFont
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    /// A secondary line that wraps within the page instead of widening it.
    static func hint(_ text: String = "") -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        styleHint(label)
        return label
    }

    static func styleHint(_ label: NSTextField) {
        label.font = hintFont
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = contentWidth
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
    }
}
