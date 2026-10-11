import Foundation
import Testing
@testable import Platypus

struct AppLanguageTests {
    @Test func followsSystemAppLanguage() {
        let expected = AppLanguage(
            rawValue: Bundle.main.preferredLocalizations.first ?? "en"
        ) ?? .english
        #expect(AppLanguage.current == expected)
    }

    @Test func languageIdentifiers() {
        #expect(AppLanguage.english.rawValue == "en")
        #expect(AppLanguage.german.rawValue == "de")
        #expect(AppLanguage.german.speechLanguage == "de-DE")
        #expect(AppLanguage.english.speechLanguage == "en-GB")
    }

    @Test func translatesDynamicText() {
        #expect(AppLanguage.german.localized("Car") == "Auto")
        #expect(AppLanguage.german.localized("Outside") == "Draußen")
        #expect(AppLanguage.english.localized("Car") == "Car")
        #expect(AppLanguage.german.format("Active profile: %@", "Test") == "Aktives Profil: Test")
        #expect(AppLanguage.german.format("%.1f meters", 1.5) == "1,5 Meter")
    }

    @Test func localizationDoesNotChangePersistedIdentifiers() {
        #expect(PlatyDetectionType.car.rawValue == "Car")
        #expect(PlatyLocationTag.outside.rawValue == "Outside")
    }
}
