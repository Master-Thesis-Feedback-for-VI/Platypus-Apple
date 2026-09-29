//
//  ActionFeedbackSettings.swift
//  Platypus
//
//  Created by Yann Bernard on 29.09.26.
//

import Foundation

struct ActionFeedbackSettings: Codable, Equatable {
    var soundSetting: SoundVariantFeedback
    var haptic: Bool

    static let `default` = ActionFeedbackSettings(
        soundSetting: .earcon,
        haptic: true
    )
}

enum SoundVariantFeedback: String, Codable, CaseIterable {
    case earcon = "Earcon"
    case tts = "Text To Speech"
    case off = "Off"
    
    var icon: String {
        switch self {
        case .earcon: "music.note"
        case .tts: "microphone"
        case .off: "nosign"
        }
    }
}
