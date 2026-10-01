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
//    var detectionSettings: [ProfileDetectionTypes: ProfileDetectionSettings]
    var _settings: [ProfileLocationTag: ProfileSingularSettings]
    var settings: ProfileSingularSettings {
        get {
            _settings[.inside]!
        }
        set {
            _settings[.inside]! = newValue
        }
    }

    init(
        name: String,
        isActive: Bool = false
    ) {
        self.name = name
        self.isActive = isActive
        
        
        var collectSettings: [ProfileLocationTag: ProfileSingularSettings] = [:]
        for profileTag in ProfileLocationTag.allCases {
            let tmpDetectionSettings = ProfileDetectionSettings.defaults()
            collectSettings[profileTag] = ProfileSingularSettings(detectionSettings: tmpDetectionSettings)
        }
        
        self._settings = collectSettings
    }
}

enum ProfileLocationTag: String, CaseIterable, Identifiable, Codable {
    case generalSetting = "General Settings"
    case inside = "Inside"
    case outside = "Outside"
    
    var id: Self { self }
}
