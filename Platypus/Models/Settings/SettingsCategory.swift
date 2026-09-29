//
//  SettingsCategory.swift
//  Platypus
//
//  Created by Yann Bernard on 29.09.26.
//

import Foundation

enum SettingsCategory: String, CaseIterable, Hashable, Identifiable {
    case detection = "Detection"

    var id: Self { self }
    var icon: String {
        switch self {
        case .detection: "photo.artframe"
        }
    }
}
