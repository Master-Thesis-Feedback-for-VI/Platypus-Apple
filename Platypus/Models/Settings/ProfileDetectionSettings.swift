//
//  ProfileDetectionSettings.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import Foundation
import SwiftData

protocol SpecificSoundSetting: Codable, CustomStringConvertible, Equatable {}

struct OffSetting: SpecificSoundSetting {
    var description: String = "off"
}

struct EarconSetting: SpecificSoundSetting {
    var description: String = "earcon"
    var volume: Float {
        didSet { volume = min(max(volume, 0), 1) }
    }
}

struct TtsSetting: SpecificSoundSetting {
    var description: String = "tts"
    var volume: Float {
        didSet { volume = min(max(volume, 0), 1) }
    }
    var enableDirectionControl: Bool = false
    var enableDistanceEstimation: Bool = false
}

enum SoundVariant: Codable, Equatable {
    case earcon(EarconSetting)
    case tts(TtsSetting)
    case off(OffSetting)
}

extension SoundVariant: CustomStringConvertible, CaseIterable {
    var isOff: Bool {
        if case .off = self { true } else { false }
    }

    static var allCases: [SoundVariant] = [
        .earcon(EarconSetting(volume: 0.5)),
        .tts(TtsSetting(volume: 0.5)),
        .off(OffSetting()),
    ]

    static var allNames: [String] {
        allCases.map { String(describing: $0) }
    }

    var settings: any SpecificSoundSetting {
        let setting: any SpecificSoundSetting
        switch self {
        case .earcon(let s): setting = s
        case .off(let s): setting = s
        case .tts(let s): setting = s
        }

        return setting
    }

    var description: String { settings.description }
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
    var sound: SoundVariant
    var haptic: HapticSettings

    static func defaults() -> [PlatyDetectionType: ProfileDetectionSettings] {
        var settings: [PlatyDetectionType: ProfileDetectionSettings] = [:]

        for type in PlatyDetectionType.allCases {
            settings[type] = ProfileDetectionSettings(
                sound: .earcon(EarconSetting(volume: 0.5)),
                haptic: .init(switchedOn: true, intensity: 0.5)
            )
        }

        return settings
    }
}
