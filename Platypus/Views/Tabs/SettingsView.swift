//
//  SettingsView.swift
//  Platypus
//
//  Created by Yann Bernard on 29.09.26.
//

import SwiftUI

struct SettingsView: View {
    @Bindable private var store = SettingsStore.share

    @AccessibilityFocusState private var focusID: UUID?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Form {
            ForEach(SettingsDetectionType.allCases) { type in
                Section(type.rawValue.capitalized) {
                    Picker("Sound", selection: binding(for: type).soundSetting)
                    {
                        ForEach(SoundVariantFeedback.allCases, id: \.self) { soundVariant in
                            Text(soundVariant.rawValue).tag(soundVariant)
                        }
                    }
                    Toggle("Haptic", isOn: binding(for: type).haptic)
                }
            }
        }
        .navigationTitle("Detection")
    }

    private func binding(for type: SettingsDetectionType) -> Binding<
        ActionFeedbackSettings
    > {
        Binding(
            get: { store.feedback[type] ?? .default },
            set: { store.feedback[type] = $0 }
        )
    }
}
