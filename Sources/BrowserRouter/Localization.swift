import Foundation

/// The language the app UI is shown in, chosen in Settings → Basic.
enum AppLanguage: String, CaseIterable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    private static let defaultsKey = "appLanguage"

    static var current: AppLanguage {
        get {
            UserDefaults.standard.string(forKey: defaultsKey).flatMap(AppLanguage.init(rawValue:)) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            localizationBundle = newValue.bundle
        }
    }

    /// Language names are shown in their own language so they stay recognizable after switching.
    var title: String {
        switch self {
        case .system:
            return L("System Default")
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    fileprivate var bundle: Bundle {
        guard self != .system,
              let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return .main
        }
        return bundle
    }
}

/// Keys are the English text, so a key missing from a strings file falls back to English.
private var localizationBundle = AppLanguage.current.bundle

func L(_ key: String) -> String {
    localizationBundle.localizedString(forKey: key, value: key, table: nil)
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    let format = localizationBundle.localizedString(forKey: key, value: key, table: nil)
    return String(format: format, locale: Locale.current, arguments: arguments)
}
