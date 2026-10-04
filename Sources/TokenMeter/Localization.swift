import Foundation

/// UI language. With only two languages, strings live inline at the call site as `tr(polish, english)`.
enum Language: String, CaseIterable {
    case system, polish = "pl", english = "en"

    private static let defaultsKey = "language"

    static var current: Language {
        get { UserDefaults.standard.string(forKey: defaultsKey).flatMap(Language.init) ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    /// `.system` follows the first preferred macOS language, falling back to English.
    static var isPolish: Bool {
        switch current {
        case .polish: true
        case .english: false
        case .system: Locale.preferredLanguages.first?.hasPrefix("pl") ?? false
        }
    }

    var label: String {
        switch self {
        case .system: tr("Systemowy", "System")
        case .polish: "Polski"
        case .english: "English"
        }
    }
}

func tr(_ polish: String, _ english: String) -> String {
    Language.isPolish ? polish : english
}
