//
//  ProfileSettings.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import SwiftData
import Foundation

@Model
final class ProfileSettings {
    @Attribute(.unique) var name: String

    var deletedAt: Date? = nil
    var isActive: Bool = false
    var settings: [ProfileLocationTag: ProfileSingularSettings]
    var created: Date

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

enum ProfileLocationTag: String, CaseIterable, Identifiable, Codable {
    case inside = "Inside"
    case outside = "Outside"

    var id: Self { self }
}
