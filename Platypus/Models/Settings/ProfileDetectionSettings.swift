//
//  ProfileDetectionSettings.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import Foundation
import SwiftData

enum SoundVariants: String, Codable, CaseIterable {
    case earcon, tts, off
}

struct SoundSettings: Codable, Equatable {
    var soundVariant: SoundVariants
    var volume: Double {
        didSet { volume = min(max(volume, 0), 1) }
    }

    init(soundVariant: SoundVariants, volume: Double) {
        self.soundVariant = soundVariant
        self.volume = min(max(volume, 0), 1)
    }
}

struct HapticSettings: Codable, Equatable {
    var switchedOn: Bool
    var intensity: Double {
        didSet { intensity = min(max(intensity, 0), 1) }
    }

    init(switchedOn: Bool, intensity: Double) {
        self.switchedOn = switchedOn
        self.intensity = min(max(intensity, 0), 1)
    }
}

struct ProfileDetectionSettings: Codable, Equatable {
    var sound: SoundSettings
    var haptic: HapticSettings

    static func defaults() -> [PlatyDetectionType: ProfileDetectionSettings]
    {
        Dictionary(
            uniqueKeysWithValues: PlatyDetectionType.allCases.map { type in
                (
                    type,
                    ProfileDetectionSettings(
                        sound: .init(soundVariant: .earcon, volume: 0.5),
                        haptic: .init(switchedOn: true, intensity: 0.5)
                    )
                )
            }
        )
    }
}
