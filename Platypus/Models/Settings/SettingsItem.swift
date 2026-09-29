//
//  SettingsItem.swift
//  Platypus
//
//  Created by Yann Bernard on 29.09.26.
//

import Foundation

struct SettingsItem: Identifiable {
    let id = UUID()
    let title: String
    let categories: SettingsCategory
}

