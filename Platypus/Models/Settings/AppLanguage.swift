import Foundation

enum AppLanguage: String {
    case english = "en"
    case german = "de"

    static var current: AppLanguage {
        // iOS resolves this using the app language selected in Apple Settings,
        // falling back to the device's preferred supported language.
        AppLanguage(rawValue: Bundle.main.preferredLocalizations.first ?? "en")
            ?? .english
    }

    var locale: Locale { Locale(identifier: rawValue) }
    var speechLanguage: String { self == .german ? "de-DE" : "en-GB" }

    func localized(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: localized(key), locale: locale, arguments: arguments)
    }
}
