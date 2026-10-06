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
    var settings: [PlatyLocationTag: ProfileSingularSettings]
    var created: Date

    init(
        name: String,
        isActive: Bool = false
    ) {
        self.name = name
        self.isActive = isActive

        var collectSettings: [PlatyLocationTag: ProfileSingularSettings] = [:]
        for locationTag in PlatyLocationTag.allCases {
            let tmpDetectionSettings = ProfileDetectionSettings.defaults(
                location: locationTag
            )
            collectSettings[locationTag] = ProfileSingularSettings(
                detectionSettings: tmpDetectionSettings
            )
        }
        self.created = Date.now
        self.settings = collectSettings
    }
}

extension ProfileSettings {
    var allSingularSettings: [ProfileSingularSettings] {
        settings.map { _key, item in
            item
        }
    }
}
