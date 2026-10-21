//
//  PlatypusTests.swift
//  PlatypusTests
//
//  Created by Yann Bernard on 07.08.26.
//

import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import Platypus

struct PlatypusTests {
    @MainActor
    @Test func centralOnlySettingsRoundTrip() throws {
        let original = ProfileDetectionSettings(
            sound: .earcon(EarconSetting(volume: 0.5)),
            haptic: HapticSettings(switchedOn: true, intensity: 0.5)
        )
        #expect(!original.soundOnlyTriggerIfCentral)
        #expect(!original.hapticOnlyTriggerIfCentral)

        var enabled = original
        enabled.soundOnlyTriggerIfCentral = true
        #expect(
            try JSONDecoder().decode(
                ProfileDetectionSettings.self,
                from: JSONEncoder().encode(enabled)
            ) == enabled
        )
    }

    @MainActor
    @Test func centralOnlyFiltersBeforeSelectingClosestObject() {
        func detection(x: CGFloat, distance: Float) -> PlatyDetection {
            PlatyDetection(
                confidence: 1,
                detectionType: .person,
                distance: distance,
                rect: CGRect(x: x - 10, y: 0, width: 20, height: 20),
                viewportSize: CGSize(width: 300, height: 300)
            )
        }

        let central = detection(x: 150, distance: 5)
        let left = detection(x: 50, distance: 1)
        let right = detection(x: 250, distance: 2)
        #expect(central.isCentral)
        #expect(!left.isCentral)
        #expect(!right.isCentral)
        #expect(detection(x: 100, distance: 1).isCentral)
        #expect(detection(x: 200, distance: 1).isCentral)

        let detections = PlatyDetections(inner: [left, right, central])
        var settings = ProfileDetectionSettings.defaults()
        #expect(detections.filteredForFeedback(settings: settings, channel: .sound).inner.count == 3)
        settings[.person]?.soundOnlyTriggerIfCentral = true
        let filtered = detections.filteredForFeedback(settings: settings, channel: .sound)
        #expect(filtered.inner == [central])
        #expect(filtered.closestDetection == central)
        #expect(PlatyDetections(inner: [left, right]).filteredForFeedback(settings: settings, channel: .sound).inner.isEmpty)
        #expect(detections.filteredForFeedback(settings: settings, channel: .haptic).closestDetection == left)
        settings[.person]?.soundOnlyTriggerIfCentral = false
        settings[.person]?.hapticOnlyTriggerIfCentral = true
        #expect(detections.filteredForFeedback(settings: settings, channel: .sound).closestDetection == left)
        #expect(detections.filteredForFeedback(settings: settings, channel: .haptic).inner == [central])
        settings[.person]?.soundOnlyTriggerIfCentral = true
        #expect(detections.filteredForFeedback(settings: settings, channel: .sound).inner == [central])
    }

    @MainActor
    @Test func ttsSpeedDefaultsForNewSettings() {
        let settings = TtsSetting(volume: 0.7)

        #expect(settings.speed == 0.5)
        #expect(settings.volume == 0.7)
        #expect(!settings.enableDirectionControl)
        #expect(!settings.enableDistanceEstimation)
    }

    @MainActor
    @Test func ttsSpeedSurvivesSoundSettingsRoundTrip() throws {
        let sound = SoundVariant.tts(TtsSetting(volume: 0.7, speed: 0.8))
        let data = try JSONEncoder().encode(sound)

        #expect(try JSONDecoder().decode(SoundVariant.self, from: data) == sound)
    }

    @MainActor
    @Test func ttsSpeedStaysWithinSliderRange() {
        var settings = TtsSetting(volume: 0.5)
        settings.speed = -1
        #expect(settings.speed == 0)
        settings.speed = 2
        #expect(settings.speed == 1)

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
