//
//  SettingsDetectionType.swift
//  Platypus
//
//  Created by Yann Bernard on 29.09.26.
//

enum SettingsDetectionType: String, CaseIterable, Identifiable, Codable {
    case car, person, bench, bicycle, trafficLight
    var id: Self { self }

    var key: String { "detection.\(rawValue)" }
}
