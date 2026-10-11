//
//  ProfileEditSingularView.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import SwiftData
import SwiftUI

// MARK: - Accessibility focus

enum SettingsA11yFocus: Hashable {
    case sound(PlatyDetectionType)
    case haptic(PlatyDetectionType)
    case location(PlatyLocationTag)
}

// MARK: - Parent

struct ProfileEditSingularView: View {
    private var language: AppLanguage { .current }
    @Bindable var profile: ProfileSettings
    @AccessibilityFocusState private var a11yFocus: SettingsA11yFocus?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn

    var body: some View {
        Form {
            Section {
                NavigationLink(language.localized("Default detection settings"))
                {
                    ProfileDetectionSettingsView(
                        settings: $profile.defaultSettings
                    )
                    .navigationTitle(
                        language.localized("Default detection settings")
                    )
                    .navigationBarTitleDisplayMode(.inline)
                }
                .accessibilityHint(
                    Text(
                        verbatim: language.localized(
                            "Used for locations without their own detection settings."
                        )
                    )
                )
            } footer: {
                Text(
                    verbatim: language.localized(
                        "These settings apply to all locations unless a location is enabled below."
                    )
                )
            }

            Section(language.localized("Locations")) {
                ForEach(PlatyLocationTag.allCases) { location in
                    Toggle(
                        language.localized(location.rawValue),
                        isOn: locationEnabledBinding(for: location)
                    )
                    .accessibilityFocused(
                        $a11yFocus,
                        equals: .location(location)
                    )
                    .accessibilityLabel(
                        Text(
                            verbatim: language.format(
                                "Enable %@ settings",
                                language.localized(location.rawValue)
                            )
                        )
                    )
                    .accessibilityHint(
                        Text(
                            verbatim: language.localized(
                                "When on, this location uses its own detection settings."
                            )
                        )
                    )

                    if profile.isLocationEnabled(location),
                        let binding = settingsBinding(for: location)
                    {
                        NavigationLink(
                            language.format(
                                "Edit %@ settings",
                                language.localized(location.rawValue)
                            )
                        ) {
                            ProfileDetectionSettingsView(settings: binding)
                                .navigationTitle(
                                    language.format(
                                        "%@ detection settings",
                                        language.localized(location.rawValue)
                                    )
                                )
                                .navigationBarTitleDisplayMode(.inline)
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
                if voiceOverOn {
                    profile.setLocation(location, enabled: enabled)
                } else {
                    withAnimation {
                        profile.setLocation(location, enabled: enabled)
                    }
                }
                restoreFocus(.location(location))
            }
        )
    }

    private func restoreFocus(_ target: SettingsA11yFocus) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            a11yFocus = target
        }
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
    private var language: AppLanguage { .current }
    @Binding var settings: ProfileSingularSettings
    @AccessibilityFocusState private var a11yFocus: SettingsA11yFocus?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn

    var body: some View {
        Form {
            ForEach(PlatyDetectionType.allCases, id: \.self) { detectionType in
                if let binding = binding(for: detectionType) {
                    Section(language.localized(detectionType.rawValue)) {
                        SoundSettingsRows(
                            detectionName: language.localized(
                                detectionType.rawValue
                            ),
                            sound: binding.sound,
                            focus: $a11yFocus,
                            focusID: .sound(detectionType)
                        )
                        HapticSettingsRows(
                            detectionName: language.localized(
                                detectionType.rawValue
                            ),
                            haptic: binding.haptic,
                            focus: $a11yFocus,
                            focusID: .haptic(detectionType)
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
                if voiceOverOn {
                    settings.detectionSettings[type] = newVal
                } else {
                    withAnimation(.snappy) {
                        settings.detectionSettings[type] = newVal
                    }
                }
            }
        )
    }
}

// MARK: - Audio

struct SoundSettingsRows: View {
    private var language: AppLanguage { .current }
    let detectionName: String
    @Binding var sound: SoundVariant
    var focus: AccessibilityFocusState<SettingsA11yFocus?>.Binding
    let focusID: SettingsA11yFocus

    var body: some View {
        Picker(selection: nameBinding) {
            ForEach(SoundVariant.allNames, id: \.self) { name in
                Text(
                    verbatim: language.localized(
                        name == "tts" ? "Text to speech" : name.capitalized
                    )
                )
                .tag(name)
            }
        } label: {
            Label(
                language.localized("Sound"),
                systemImage: "speaker.wave.2.fill"
            )
        }
        .pickerStyle(.menu)
        .accessibilityFocused(focus, equals: focusID)
        .accessibilityLabel(
            Text(verbatim: language.format("%@ sound", detectionName))
        )
        .accessibilityValue(
            Text(
                verbatim: language.localized(
                    sound.description == "tts"
                        ? "Text to speech" : sound.description.capitalized
                )
            )
        )
        .accessibilityHint(
            Text(
                verbatim: language.localized(
                    "Choose off, earcon, or text to speech."
                )
            )
        )

        if !sound.isOff {
            SliderRow(
                label: "Volume",
                accessibilityName: AppLanguage.current.format(
                    "%@ volume",
                    detectionName
                ),
                value: volumeBinding,
                minIcon: "speaker.fill",
                maxIcon: "speaker.wave.3.fill"
            )

            if case .tts = sound {
                Toggle(isOn: directionControlBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(
                            language.localized("Direction Control"),
                            systemImage: "location.north.line.fill"
                        )
                        Text(
                            verbatim: language.localized(
                                "Announces where the detection is relative to you."
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(
                    Text(
                        verbatim: language.format(
                            "%@ direction announcements",
                            detectionName
                        )
                    )
                )
                .accessibilityHint(
                    Text(
                        verbatim: language.localized(
                            "Speaks the detection's direction."
                        )
                    )
                )

                Toggle(isOn: distanceEstimationBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(
                            language.localized("Distance Estimator"),
                            systemImage: "base.unit"
                        )
                        Text(
                            verbatim: language.localized(
                                "Announces how far the detection is relative to you."
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(
                    Text(
                        verbatim: language.format(
                            "%@ distance announcements",
                            detectionName
                        )
                    )
                )
                .accessibilityHint(
                    Text(
                        verbatim: language.localized(
                            "Speaks the detection's distance."
                        )
                    )
                )
            }
        }
    }

    private func restoreFocus() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            focus.wrappedValue = focusID
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
                    restoreFocus()
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
    @Binding var haptic: HapticSettings
    var focus: AccessibilityFocusState<SettingsA11yFocus?>.Binding
    let focusID: SettingsA11yFocus

    var body: some View {
        Toggle(isOn: switchBinding) {
            Label(
                AppLanguage.current.localized("Haptics"),
                systemImage: "iphone.radiowaves.left.and.right"
            )
        }
        .accessibilityFocused(focus, equals: focusID)
        .accessibilityLabel(
            Text(
                verbatim: AppLanguage.current.format(
                    "%@ haptics",
                    detectionName
                )
            )
        )

        if haptic.switchedOn {
            SliderRow(
                label: "Intensity",
                accessibilityName: AppLanguage.current.format(
                    "%@ haptic intensity",
                    detectionName
                ),
                value: $haptic.intensity,
                minIcon: "circle",
                maxIcon: "circle.fill"
            )
        }
    }

    private func restoreFocus() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            focus.wrappedValue = focusID
        }
    }

    private var switchBinding: Binding<Bool> {
        Binding(
            get: { haptic.switchedOn },
            set: { newValue in
                haptic.switchedOn = newValue
                restoreFocus()
            }
        )
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
                Text(verbatim: AppLanguage.current.localized(label))
                Spacer()
                Text(
                    Double(value).formatted(
                        .percent.precision(.fractionLength(0)).locale(
                            AppLanguage.current.locale
                        )
                    )
                )
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .accessibilityHidden(true)

            Slider(value: $value, in: 0...1, step: 0.1) {
                Text(verbatim: AppLanguage.current.localized(label))
            } minimumValueLabel: {
                Image(systemName: minIcon)
                    .accessibilityHidden(true)
            } maximumValueLabel: {
                Image(systemName: maxIcon)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text(verbatim: accessibilityName))
            .accessibilityValue(
                Text(
                    verbatim: Double(value).formatted(
                        .percent.precision(.fractionLength(0)).locale(
                            AppLanguage.current.locale
                        )
                    )
                )
            )
        }
        .padding(.vertical, 2)
    }
}
