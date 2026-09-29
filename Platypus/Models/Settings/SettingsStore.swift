//
//  SettingsStore.swift
//  Platypus
//
//  Created by Yann Bernard on 29.09.26.
//

import Foundation
import Observation

@Observable
final class SettingsStore {
    static let share = SettingsStore()

    private let defaults: UserDefaults

    var feedback: [SettingsDetectionType: ActionFeedbackSettings] = [:] {
        didSet { persist(oldValue) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loaded: [SettingsDetectionType: ActionFeedbackSettings] = [:]
        for type in SettingsDetectionType.allCases {
            loaded[type] =
                Self.load(
                    ActionFeedbackSettings.self,
                    key: type.key,
                    from: defaults
                )
                ?? .default
        }
        feedback = loaded
    }

    private func persist(_ old: [SettingsDetectionType: ActionFeedbackSettings]) {
        for (type, value) in feedback where old[type] != value {
            if let data = try? JSONEncoder().encode(value) {
                defaults.set(data, forKey: type.key)
            }
        }
    }

    private static func load<T: Decodable>(
        _ type: T.Type,
        key: String,
        from defaults: UserDefaults
    ) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
