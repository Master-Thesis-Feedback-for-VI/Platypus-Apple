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
                    ProfileDetectionSettingsView(
                        settings: $profile.defaultSettings
                    )
                    .navigationTitle("Default detection settings")
                }
                .accessibilityHint(
                    "Used for locations without their own detection settings."
                )
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
                    .accessibilityLabel("Enable \(location.rawValue) settings")
                    .accessibilityHint(
                        "When on, this location uses its own detection settings."
                    )

                    if profile.isLocationEnabled(location),
                        let binding = settingsBinding(for: location)
                    {
                        NavigationLink("Edit \(location.rawValue) settings") {
                            ProfileDetectionSettingsView(settings: binding)
                                .navigationTitle(
                                    "\(location.rawValue) detection settings"
                                )
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
                withAnimation {
                    profile.setLocation(location, enabled: enabled)
                }
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
                        SoundSettingsRows(
                            detectionName: detectionType.rawValue,
                            sound: binding.sound
                        )
                        HapticSettingsRows(
                            detectionName: detectionType.rawValue,
                            haptic: binding.haptic
                        )
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
    let detectionName: String
    @Binding var sound: SoundVariant

    var body: some View {
        Picker(selection: nameBinding) {
            ForEach(SoundVariant.allNames, id: \.self) { name in
                Text(name == "tts" ? "Text to speech" : name.capitalized)
                    .tag(name)
            }
        } label: {
            Label("Sound", systemImage: "speaker.wave.2.fill")
        }
        .pickerStyle(.menu)
        .accessibilityLabel("\(detectionName) sound")
        .accessibilityValue(
            sound.description == "tts"
                ? "Text to speech" : sound.description.capitalized
        )
        .accessibilityHint("Choose off, earcon, or text to speech.")

        if !sound.isOff {
            SliderRow(
                label: "Volume",
                accessibilityName: "\(detectionName) volume",
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
                .accessibilityLabel("\(detectionName) direction announcements")
                .accessibilityHint("Speaks the detection's direction.")

                Toggle(isOn: distanceEstimationBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(
                            "Distance Estimator",
                            systemImage: "base.unit"
                        )
                        Text(
                            "Announces how far the detection is relative to you."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("\(detectionName) distance announcements")
                .accessibilityHint("Speaks the detection's distance.")
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

    private var distanceEstimationBinding: Binding<Bool> {
        Binding(
            get: {
                if case .tts(let s) = sound {
                    return s.enableDistanceEstimation
                }
                return false
            },
            set: { newValue in
                if case .tts(var s) = sound {
                    s.enableDistanceEstimation = newValue
                    sound = .tts(s)
                }
            }
        )
    }
}

// MARK: - Haptics

struct HapticSettingsRows: View {
    let detectionName: String
    @Binding var haptic: HapticSettings  // replace with your actual haptic type

    var body: some View {
        Toggle(isOn: $haptic.switchedOn) {
            Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
        }
        .accessibilityLabel("\(detectionName) haptics")

        if haptic.switchedOn {
            SliderRow(
                label: "Intensity",
                accessibilityName: "\(detectionName) haptic intensity",
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
    let accessibilityName: String
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
            .accessibilityHidden(true)

            Slider(value: $value, in: 0...1, step: 0.2) {
                Text(label)
            } minimumValueLabel: {
                Image(systemName: minIcon)
                    .accessibilityHidden(true)
            } maximumValueLabel: {
                Image(systemName: maxIcon)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel(accessibilityName)
            .accessibilityValue(
                Double(value).formatted(.percent.precision(.fractionLength(0)))
            )
        }
        .padding(.vertical, 2)
    }
}
