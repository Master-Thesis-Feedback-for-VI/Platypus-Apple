//
//  PlatypusTests.swift
//  PlatypusTests
//
//  Created by Yann Bernard on 07.08.26.
//

import Foundation
import SwiftData
import Testing
@testable import Platypus

struct PlatypusTests {
    @MainActor
    @Test func ttsSpeedDefaultsForExistingSettings() throws {
        let data = Data(
            #"{"description":"tts","volume":0.7,"enableDirectionControl":true,"enableDistanceEstimation":false}"#.utf8
        )
        let settings = try JSONDecoder().decode(TtsSetting.self, from: data)

        #expect(settings.speed == 0.5)
        #expect(settings.volume == 0.7)
        #expect(settings.enableDirectionControl)
        #expect(!settings.enableDistanceEstimation)
    }

    @MainActor
    @Test func ttsSpeedSurvivesSoundSettingsRoundTrip() throws {
        let sound = SoundVariant.tts(TtsSetting(volume: 0.7, speed: 0.8))
        let data = try JSONEncoder().encode(sound)

        #expect(try JSONDecoder().decode(SoundVariant.self, from: data) == sound)
    }

    @MainActor
    @Test func ttsSpeedStaysWithinSliderRange() throws {
        var settings = TtsSetting(volume: 0.5)
        settings.speed = -1
        #expect(settings.speed == 0)
        settings.speed = 2
        #expect(settings.speed == 1)

        let data = Data(
            #"{"description":"tts","volume":0.5,"speed":2,"enableDirectionControl":false,"enableDistanceEstimation":false}"#.utf8
        )
        #expect(try JSONDecoder().decode(TtsSetting.self, from: data).speed == 1)
    }

    @MainActor
    @Test func profileNavigationRefreshesProfilesChangedElsewhere() throws {
        let container = try ModelContainer(
            for: Schema([ProfileSettings.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let manager = ProfileManager(context: context)
        let original = manager.currentProfile

        let added = ProfileSettings(name: "TTS")
        added.setLocation(.inside, enabled: true)
        var inside = added.settings[.inside]!
        inside.detectionSettings[.car]!.sound = .tts(TtsSetting(volume: 0.5))
        added.settings[.inside] = inside
        context.insert(added)
        try context.save()

        try manager.next()
        #expect(manager.currentProfile === added)
        #expect(manager.settings(for: .inside)?.profileID == added.persistentModelID)
        #expect(
            manager.settings(for: .inside)?.settings
                .detectionSettings[.car]?.sound
                == .tts(TtsSetting(volume: 0.5))
        )

        original.isActive = false
        original.deletedAt = .now
        try context.save()

        try manager.next()
        #expect(manager.currentProfile === added)
        #expect(manager.profiles.count == 1)
    }

    @MainActor
    @Test func disabledLocationsUseDefaultAndRetainOverrides() throws {
        let container = try ModelContainer(
            for: Schema([ProfileSettings.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let manager = ProfileManager(context: context)
        let profile = manager.currentProfile

        #expect(profile.enabledLocations.isEmpty)
        #expect(profile.settings.isEmpty)

        var defaults = profile.defaultSettings
        defaults.detectionSettings[.car]!.sound = .tts(TtsSetting(volume: 0.5))
        profile.defaultSettings = defaults
        #expect(manager.settings(for: .forest)?.settings == defaults)
        #expect(manager.settings(for: .inside)?.settings == defaults)

        profile.setLocation(.forest, enabled: true)
        #expect(profile.settings[.forest] == defaults)
        var override = profile.settings[.forest]!
        override.detectionSettings[.car]!.sound = .earcon(EarconSetting(volume: 0.5))
        var overrides = profile.settings
        overrides[.forest] = override
        profile.settings = overrides

        #expect(manager.settings(for: .forest)?.settings == override)
        #expect(manager.settings(for: .inside)?.settings == defaults)

        profile.setLocation(.forest, enabled: false)
        #expect(manager.settings(for: .forest)?.settings == defaults)
        try context.save()

        let reopened = ProfileManager(context: ModelContext(container))
        #expect(reopened.settings(for: .forest)?.settings == defaults)
        reopened.currentProfile.setLocation(.forest, enabled: true)
        #expect(reopened.settings(for: .forest)?.settings == override)
    }
}
