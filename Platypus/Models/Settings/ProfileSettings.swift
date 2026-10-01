//
//  ProfileSettings.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import SwiftData

@Model
final class ProfileSettings {
    @Attribute(.unique) var name: String

    var isActive: Bool = false
    var settings: [ProfileLocationTag: ProfileSingularSettings]

    init(
        name: String,
        isActive: Bool = false
    ) {
        self.name = name
        self.isActive = isActive

        var collectSettings: [ProfileLocationTag: ProfileSingularSettings] = [:]
        for profileTag in ProfileLocationTag.allCases {
            let tmpDetectionSettings = ProfileDetectionSettings.defaults()
            collectSettings[profileTag] = ProfileSingularSettings(
                detectionSettings: tmpDetectionSettings
            )
        }

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

enum ProfileLocationTag: String, CaseIterable, Identifiable, Codable {
    case inside = "Inside"
    case outside = "Outside"

    var id: Self { self }
}
