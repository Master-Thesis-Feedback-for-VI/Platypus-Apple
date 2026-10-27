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
        #expect(AppLanguage.german.localized("Cyclist") == "Radfahrer")
        #expect(AppLanguage.english.localized("Cyclist") == "Cyclist")
        #expect(AppLanguage.german.format("Active profile: %@", "Test") == "Aktives Profil: Test")
        #expect(AppLanguage.german.format("%.1f meters", 1.5) == "1,5 Meter")
    }

    @Test func localizesProfileNameAccessibility() {
        let hint = "Edit the profile name, then tap Done to save it."
        #expect(AppLanguage.german.localized("Profile name") == "Profilname")
        #expect(
            AppLanguage.german.localized(hint)
                == "Bearbeite den Profilnamen und tippe zum Speichern auf Fertig."
        )
        #expect(AppLanguage.english.localized("Profile name") == "Profile name")
        #expect(AppLanguage.english.localized(hint) == hint)
    }

    @Test func localizesNewProfileName() {
        #expect(AppLanguage.german.localized("New Profile") == "Neues Profil")
        #expect(AppLanguage.english.localized("New Profile") == "New Profile")
    }

    @Test func translatesProfileControlsAndHints() {
        let keys = [
            "Default detection settings",
            "Used for locations without their own detection settings.",
            "These settings apply to all locations unless a location is enabled below.",
            "Locations", "Inside", "Outside", "Forest", "Street", "Parking", "Railway",
            "When on, this location uses its own detection settings.",
            "Car", "Bench", "Bicycle", "Sound", "Off", "Earcon", "Text to speech",
            "Choose off, earcon, or text to speech.", "Volume", "Direction Control",
            "Announces where the detection is relative to you.",
            "Speaks the detection's direction.", "Distance Estimator",
            "Announces how far the detection is relative to you.",
            "Speaks the detection's distance.", "Haptics", "Intensity",
            "Profile name can't be empty", "Enter a name for this profile.",
            "Choose a different name for this profile.",
        ]
        for key in keys {
            #expect(AppLanguage.german.localized(key) != key)
            #expect(AppLanguage.english.localized(key) == key)
        }
    }

    @Test func translatesInterpolatedProfileAccessibility() {
        let language = AppLanguage.german
        #expect(language.format("Enable %@ settings", "Wald") == "Einstellungen für Wald aktivieren")
        #expect(language.format("Edit %@ settings", "Wald") == "Einstellungen für Wald bearbeiten")
        #expect(language.format("%@ detection settings", "Wald") == "Erkennungseinstellungen für Wald")
        #expect(language.format("%@ sound", "Auto") == "Auto: Ton")
        #expect(language.format("%@ volume", "Auto") == "Auto: Lautstärke")
        #expect(language.format("%@ direction announcements", "Auto") == "Auto: Richtungsansagen")
        #expect(language.format("%@ distance announcements", "Auto") == "Auto: Entfernungsansagen")
        #expect(language.format("%@ haptics", "Auto") == "Auto: Haptik")
        #expect(language.format("%@ haptic intensity", "Auto") == "Auto: Haptikintensität")
        #expect(language.format("%@ already exists", "Test") == "Test existiert bereits")
    }

    @Test func translatesTabsAndGeneralViewText() {
        let translations = [
            "Live": "Live",
            "Record": "Aufnehmen",
            "Replay": "Wiedergabe",
            "Settings": "Einstellungen",
            "Available Profiles": "Verfügbare Profile",
            "Active": "Aktiv",
            "Inactive": "Inaktiv",
            "Active profile": "Aktives Profil",
            "Inactive profile": "Inaktives Profil",
            "Opens this profile's settings.": "Öffnet die Einstellungen dieses Profils.",
            "Undo": "Rückgängig",
            "Undo profile deletion": "Löschen des Profils rückgängig machen",
            "Add": "Hinzufügen",
            "Add profile": "Profil hinzufügen",
            "Creates a new profile.": "Erstellt ein neues Profil.",
            "Previous profile": "Vorheriges Profil",
            "Next profile": "Nächstes Profil",
            "Available Videos": "Verfügbare Videos",
            "Camera": "Kamera",
            "Camera not authorized": "Kein Kamerazugriff",
            "Camera Access Needed": "Kamerazugriff erforderlich",
            "Start Recording": "Aufnahme starten",
            "Stop Recording": "Aufnahme stoppen",
            "Nothing detected": "Nichts erkannt",
            "Off": "Aus",
            "Hardware": "Hardware",
            "Evaluating": "Auswertung",
            "Failed": "Fehlgeschlagen",
            "Success": "Erfolgreich",
            "Downloading": "Herunterladen",
            "Close playback": "Wiedergabe schließen",
        ]
        for (key, translation) in translations {
            #expect(AppLanguage.german.localized(key) == translation)
            #expect(AppLanguage.english.localized(key) == key)
        }
        #expect(AppLanguage.german.format("Profile %@", "Test") == "Profil Test")
        #expect(AppLanguage.german.format("Edit %@", "Test") == "Test bearbeiten")
        #expect(AppLanguage.german.format("%.1f m", 1.5) == "1,5 m")
    }

    @Test func translatesSpokenDetectionNames() {
        let translations: [PlatyDetectionType: String] = [
            .person: "Person",
            .car: "Auto",
            .cyclist: "Radfahrer",
            .bicycle: "Fahrrad",
            .bench: "Bank",
        ]
        for type in PlatyDetectionType.allCases {
            #expect(type.localizedName(in: .german) == translations[type])
            #expect(type.localizedName(in: .english) == type.rawValue.capitalized)
        }
    }

    @Test func localizationDoesNotChangePersistedIdentifiers() {
        #expect(PlatyDetectionType.car.rawValue == "car")
        #expect(PlatyLocationTag.outside.rawValue == "Outside")
    }
}
