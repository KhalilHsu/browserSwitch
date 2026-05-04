import CoreGraphics
import Foundation

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
            return L("Command + Shift")
        case .optionShift:
            return L("Option + Shift")
        case .controlShift:
            return L("Control + Shift")
        case .commandOption:
            return L("Command + Option")
        case .always:
            return L("Always show chooser")
        case .custom:
            return L("Custom...")
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
