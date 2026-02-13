import Foundation

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private enum Keys {
        static let currentLanguage = "currentLanguage"
    }

    let supportedLanguages: [String: String] = [
        "system": "language.system",
        "en": "language.english",
        "zh-Hans": "language.simplifiedChinese"
    ]

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: Keys.currentLanguage)
        }
    }

    private init() {
        currentLanguage = UserDefaults.standard.string(forKey: Keys.currentLanguage) ?? "system"
    }

    var locale: Locale {
        if currentLanguage == "system" {
            return .current
        }
        return Locale(identifier: currentLanguage)
    }

    private var bundle: Bundle {
        if currentLanguage == "system" {
            return .main
        }

        guard let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return .main
        }

        return languageBundle
    }

    func localized(_ key: String, arguments: [CVarArg] = []) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else {
            return format
        }
        return String(format: format, locale: locale, arguments: arguments)
    }
}

extension String {
    var localized: String {
        LanguageManager.shared.localized(self)
    }

    func localized(_ arguments: CVarArg...) -> String {
        LanguageManager.shared.localized(self, arguments: arguments)
    }
}
