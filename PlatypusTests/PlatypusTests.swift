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
    @Test func profileNavigationRefreshesProfilesChangedElsewhere() throws {
        let container = try ModelContainer(
            for: Schema([ProfileSettings.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let manager = ProfileManager(context: context)
        let original = manager.currentProfile

        let added = ProfileSettings(name: "TTS")
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
}
