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
    var detectionSettings: [ProfileDetectionTypes: ProfileDetectionSettings]

    init(
        name: String,
        detectionSettings: [ProfileDetectionTypes: ProfileDetectionSettings] =
            ProfileDetectionSettings.defaults(),
        isActive: Bool = false
    ) {
        self.name = name
        self.detectionSettings = detectionSettings
        self.isActive = isActive
    }
}
