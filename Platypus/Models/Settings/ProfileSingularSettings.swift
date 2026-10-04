//
//  ProfileSingularSettings.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import Foundation

struct ProfileSingularSettings: Codable {
    var detectionSettings: [PlatyDetectionType: ProfileDetectionSettings]
}
