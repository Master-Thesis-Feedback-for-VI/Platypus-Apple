//
//  ProfileSingularSettings.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import Foundation

nonisolated struct ProfileSingularSettings: Codable, Equatable {
    var detectionSettings: [PlatyDetectionType: ProfileDetectionSettings]
}
