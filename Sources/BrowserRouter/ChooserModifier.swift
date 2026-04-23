import CoreGraphics

enum ChooserModifier: String, CaseIterable {
    case commandShift = "command+shift"
    case optionShift = "option+shift"
    case controlShift = "control+shift"
    case commandOption = "command+option"
    case always = "always"
    case custom = "custom"

    var title: String {
        switch self {
        case .commandShift:
            return "Command + Shift"
        case .optionShift:
            return "Option + Shift"
        case .controlShift:
            return "Control + Shift"
        case .commandOption:
            return "Command + Option"
        case .always:
            return "Always show chooser"
        case .custom:
            return "Custom…"
        }
    }

    func matches(_ flags: CGEventFlags) -> Bool {
        switch self {
        case .commandShift:
            return flags.contains(.maskCommand) && flags.contains(.maskShift)
        case .optionShift:
            return flags.contains(.maskAlternate) && flags.contains(.maskShift)
        case .controlShift:
            return flags.contains(.maskControl) && flags.contains(.maskShift)
        case .commandOption:
            return flags.contains(.maskCommand) && flags.contains(.maskAlternate)
        case .always:
            return true
        case .custom:
            // Custom matching is handled in AppDelegate using customChooserFlags.
            return false
        }
    }
}
