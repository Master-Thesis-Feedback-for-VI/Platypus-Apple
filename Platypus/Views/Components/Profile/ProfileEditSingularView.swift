//
//  ProfileEditSingularView.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import SwiftData
import SwiftUI

// MARK: - Parent

struct ProfileEditSingularView: View {
    @Bindable var profile: ProfileSettings

    var body: some View {
        Form {
            Section {
                NavigationLink("Default detection settings") {
                    ProfileDetectionSettingsView(settings: $profile.defaultSettings)
                        .navigationTitle("Default")
                }
            } footer: {
                Text(
                    "These settings apply to all locations unless a location is enabled below."
                )
            }

            Section("Locations") {
                ForEach(PlatyLocationTag.allCases) { location in
                    Toggle(
                        location.rawValue,
                        isOn: locationEnabledBinding(for: location)
                    )

                    if profile.isLocationEnabled(location),
                        let binding = settingsBinding(for: location)
                    {
                        NavigationLink("Edit \(location.rawValue) settings") {
                            ProfileDetectionSettingsView(settings: binding)
                                .navigationTitle(location.rawValue)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func locationEnabledBinding(for location: PlatyLocationTag)
        -> Binding<Bool>
    {
        Binding(
            get: { profile.isLocationEnabled(location) },
            set: { enabled in
                withAnimation { profile.setLocation(location, enabled: enabled) }
            }
        )
    }

    private func settingsBinding(for location: PlatyLocationTag) -> Binding<
        ProfileSingularSettings
    >? {
        guard let current = profile.settings[location] else { return nil }
        return Binding(
            get: { profile.settings[location] ?? current },
            set: { newValue in
                var overrides = profile.settings
                overrides[location] = newValue
                profile.settings = overrides
            }
        )
    }
}

struct ProfileDetectionSettingsView: View {
    @Binding var settings: ProfileSingularSettings

    var body: some View {
        Form {
            ForEach(PlatyDetectionType.allCases, id: \.self) { detectionType in
                if let binding = binding(for: detectionType) {
                    Section(detectionType.rawValue.capitalized) {
                        SoundSettingsRows(sound: binding.sound)
                        HapticSettingsRows(haptic: binding.haptic)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for type: PlatyDetectionType) -> Binding<
        ProfileDetectionSettings
    >? {
        guard let current = settings.detectionSettings[type] else { return nil }
        return Binding(
            get: {
                settings.detectionSettings[type] ?? current
            },
            set: { newVal in
                withAnimation(.snappy) {
                    settings.detectionSettings[type] = newVal
                }
            }
        )
    }
}

// MARK: - Audio

struct SoundSettingsRows: View {
    @Binding var sound: SoundVariant

    var body: some View {
        Picker(selection: nameBinding) {
            ForEach(SoundVariant.allNames, id: \.self) { name in
                Text(name.capitalized).tag(name)
            }
        } label: {
            Label("Sound", systemImage: "speaker.wave.2.fill")
        }
        .pickerStyle(.menu)

        if !sound.isOff {
            SliderRow(
                label: "Volume",
                value: volumeBinding,
                minIcon: "speaker.fill",
                maxIcon: "speaker.wave.3.fill"
            )

            if case .tts = sound {
                Toggle(isOn: directionControlBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(
                            "Direction Control",
                            systemImage: "location.north.line.fill"
                        )
                        Text(
                            "Announces where the detection is relative to you."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { sound.description },
            set: { name in
                if let match = SoundVariant.allCases.first(where: {
                    $0.description == name
                }) {
                    sound = match
                }
            }
        )
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: {
                switch sound {
                case .earcon(let s): Double(s.volume)
                case .tts(let s): Double(s.volume)
                case .off: 0
                }
            },
            set: { v in
                switch sound {
                case .earcon(var s):
                    s.volume = Float(v)
                    sound = .earcon(s)
                case .tts(var s):
                    s.volume = Float(v)
                    sound = .tts(s)
                case .off:
                    break
                }
            }
        )
    }

    private var directionControlBinding: Binding<Bool> {
        Binding(
            get: {
                if case .tts(let s) = sound {
                    return s.enableDirectionControl
                }
                return false
            },
            set: { newValue in
                if case .tts(var s) = sound {
                    s.enableDirectionControl = newValue
                    sound = .tts(s)
                }
            }
        )
    }
}

// MARK: - Haptics

struct HapticSettingsRows: View {
    @Binding var haptic: HapticSettings  // replace with your actual haptic type

    var body: some View {
        Toggle(isOn: $haptic.switchedOn) {
            Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
        }

        if haptic.switchedOn {
            SliderRow(
                label: "Intensity",
                value: $haptic.intensity,
                minIcon: "circle",
                maxIcon: "circle.fill"
            )
        }
    }
}

// MARK: - Shared

struct SliderRow<V>: View
where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {
    let label: String
    @Binding var value: V
    var minIcon: String
    var maxIcon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                Text(
                    Double(value).formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            Slider(value: $value, in: 0...1, step: 0.2) {
                Text(label)
            } minimumValueLabel: {
                Image(systemName: minIcon)
            } maximumValueLabel: {
                Image(systemName: maxIcon)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
