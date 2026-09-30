//
//  ProfileEditSingularView.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import SwiftUI

struct ProfileEditSingularView: View {
    @Bindable var profile: ProfileSettings

    var body: some View {
        Form {
            TextField("Name", text: $profile.name)

            ForEach(ProfileDetectionTypes.allCases) { type in
                if let binding = binding(for: type) {
                    Section(type.rawValue) {
                        Picker("Sound", selection: binding.sound.soundVariant) {
                            ForEach(SoundVariants.allCases, id: \.self) {
                                Text($0.rawValue.capitalized).tag($0)
                            }
                        }
                        Slider(
                            value: binding.sound.volume,
                            in: 0...1,
                            step: 0.2
                        )
                        Toggle("Haptics", isOn: binding.haptic.switchedOn)
                        Slider(
                            value: binding.haptic.intensity,
                            in: 0...1,
                            step: 0.2
                        )
                    }
                }
            }
        }
    }

    private func binding(for type: ProfileDetectionTypes) -> Binding<
        ProfileDetectionSettings
    >? {
        guard profile.settings.detectionSettings[type] != nil else { return nil }
        return Binding(
            get: { profile.settings.detectionSettings[type]! },
            set: { profile.settings.detectionSettings[type] = $0 }
        )
    }
}
