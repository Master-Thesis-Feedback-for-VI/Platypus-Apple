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

extension ProfileSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case deletedAt
        case isActive
        case defaultSettings
        case enabledLocations
        case settings
        case created
    }

    convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        let name = try c.decode(String.self, forKey: .name)
        let isActive = try c.decode(Bool.self, forKey: .isActive)

        self.init(name: name, isActive: isActive)

        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        defaultSettings = try c.decode(
            ProfileSingularSettings.self,
            forKey: .defaultSettings
        )
        enabledLocations = try c.decode(
            [PlatyLocationTag].self,
            forKey: .enabledLocations
        )
        settings = try c.decode(
            [PlatyLocationTag: ProfileSingularSettings].self,
            forKey: .settings
        )
        created = try c.decode(Date.self, forKey: .created)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try c.encode(isActive, forKey: .isActive)
        try c.encode(defaultSettings, forKey: .defaultSettings)
        try c.encode(enabledLocations, forKey: .enabledLocations)
        try c.encode(settings, forKey: .settings)
        try c.encode(created, forKey: .created)
    }
}
