//
//  ProfileSettings.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import Foundation
import SwiftData

@Model
final class ProfileSettings {
    @Attribute(.unique) var name: String

    var deletedAt: Date? = nil
    var isActive: Bool = false
    var defaultSettings: ProfileSingularSettings
    var enabledLocations: [PlatyLocationTag]
    var settings: [PlatyLocationTag: ProfileSingularSettings]
    var created: Date

    init(
        name: String,
        isActive: Bool = false
    ) {
        self.name = name
        self.isActive = isActive

        self.defaultSettings = ProfileSingularSettings(
            detectionSettings: ProfileDetectionSettings.defaults()
        )
        self.enabledLocations = []
        self.created = Date.now
        self.settings = [:]
    }
}

extension ProfileSettings {
    func isLocationEnabled(_ location: PlatyLocationTag) -> Bool {
        enabledLocations.contains(location)
    }

    func setLocation(_ location: PlatyLocationTag, enabled: Bool) {
        if enabled {
            guard !isLocationEnabled(location) else { return }
            if !settings.keys.contains(location) {
                var overrides = settings
                overrides[location] = defaultSettings
                settings = overrides
            }
            enabledLocations = enabledLocations + [location]
        } else {
            enabledLocations = enabledLocations.filter { $0 != location }
        }
    }
}
