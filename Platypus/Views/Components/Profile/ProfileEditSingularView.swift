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
                    .id(SettingsA11yFocus.location(location))

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
        .highContrastForm()
        .transaction { transaction in
            if voiceOverOn {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
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
        guard voiceOverOn else { return }
        // Re-request focus even when this control was already focused before
        // its dependent rows were removed from the form.
        a11yFocus = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
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
                    Section(
                        language.localized(detectionType.rawValue.capitalized)
                    ) {
                        SoundSettingsRows(
                            detectionType: detectionType,
                            detectionName: language.localized(
                                detectionType.rawValue
                            ),
                            focus: $a11yFocus,
                            focusID: .sound(detectionType),
                            sound: binding.sound
                        )
                        if !binding.sound.wrappedValue.isOff {
                            DistanceSliderRow(
                                maximumDistance: binding.soundMaximumDistance,
                                accessibilityName: language.format("%@ sound", language.localized(detectionType.rawValue))
                            )
                            CentralOnlyToggle(
                                isOn: binding.soundOnlyTriggerIfCentral,
                                accessibilityName: language.format("%@ sound", language.localized(detectionType.rawValue))
                            )
                        }
                        HapticSettingsRows(
                            detectionName: language.localized(
                                detectionType.rawValue
                            ),
                            haptic: binding.haptic,
                            focus: $a11yFocus,
                            focusID: .haptic(detectionType)
                        )
                        if binding.haptic.switchedOn.wrappedValue {
                            DistanceSliderRow(
                                maximumDistance: binding.hapticMaximumDistance,
                                accessibilityName: language.format("%@ haptics", language.localized(detectionType.rawValue))
                            )
                            CentralOnlyToggle(
                                isOn: binding.hapticOnlyTriggerIfCentral,
                                accessibilityName: language.format("%@ haptics", language.localized(detectionType.rawValue))
                            )
                        }

                        if binding.haptic.switchedOn.wrappedValue
                            || !binding.sound.wrappedValue.isOff
                        {
                            Toggle(isOn: binding.groupFeedback) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Label(
                                        language.localized("Group Feedback"),
                                        systemImage: "rectangle.3.group"
                                    )
                                    Text(
                                        verbatim: language.localized(
                                            "When enabled, nearby detections are combined into one group with an average distance and a single bounding box surrounding them."
                                        )
                                    )
                                    .font(.body)
                                    .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .highContrastForm()
        .transaction { transaction in
            if voiceOverOn {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
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
    let detectionType: PlatyDetectionType
    let detectionName: String
    var focus: AccessibilityFocusState<SettingsA11yFocus?>.Binding
    let focusID: SettingsA11yFocus

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    @EnvironmentObject private var earconEngine: EarconPlayer

    @Binding var sound: SoundVariant
    @State private var tts = Speaker()

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
        // Keep the picker identity independent of the number of detail rows.
        .id(focusID)

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
                SliderRow(
                    label: "Speech speed",
                    accessibilityName: language.format(
                        "%@ speech speed",
                        detectionName
                    ),
                    value: speedBinding,
                    minIcon: "tortoise.fill",
                    maxIcon: "hare.fill"
                )

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
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryText)
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
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryText)
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
        guard voiceOverOn else { return }
        focus.wrappedValue = nil
        Task { @MainActor in
            // The menu must finish dismissing before it can return focus to
            // the picker in the updated form.
            try? await Task.sleep(for: .milliseconds(300))
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
            set: { newValue in
                let volume = Float(newValue)

                switch sound {
                case .earcon(var s):
                    guard s.volume != volume else { return }
                    s.volume = volume
                    sound = .earcon(s)

                    Task { @MainActor in
                        await earconEngine.play(
                            detectionType,
                            volume: volume,
                            from: .front
                        )
                    }

                case .tts(var s):
                    guard s.volume != volume else { return }
                    s.volume = volume
                    sound = .tts(s)

                    tts.speak(
                        language.localized("Sound"),
                        volume,
                        speed: s.speed
                    )

                case .off:
                    break
                }
            }
        )
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: {
                if case .tts(let s) = sound {
                    return Double(s.speed)
                }
                return 0.5
            },
            set: { newValue in
                guard case .tts(var s) = sound else { return }
                let speed = Float(newValue)
                guard s.speed != speed else { return }
                s.speed = speed
                sound = .tts(s)
                tts.speak(
                    language.localized("Sound"),
                    s.volume,
                    speed: s.speed
                )
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
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    @EnvironmentObject private var mqttClient: PlatyMQTT

    let detectionName: String
    @Binding var haptic: HapticSettings
    var focus: AccessibilityFocusState<SettingsA11yFocus?>.Binding
    let focusID: SettingsA11yFocus

    private var language: AppLanguage { .current }

    var body: some View {
        Toggle(isOn: switchBinding) {
            Label(
                language.localized("Haptics"),
                systemImage: "iphone.radiowaves.left.and.right"
            )
        }
        .accessibilityFocused(focus, equals: focusID)
        .accessibilityLabel(
            Text(
                verbatim: language.format(
                    "%@ haptics",
                    detectionName
                )
            )
        )
        .id(focusID)

        if haptic.switchedOn {
            SliderRow(
                label: "Intensity",
                accessibilityName: AppLanguage.current.format(
                    "%@ haptic intensity",
                    detectionName
                ),
                value: intensityBinding,
                minIcon: "circle",
                maxIcon: "circle.fill"
            )
        }
    }

    private func restoreFocus() {
        guard voiceOverOn else { return }
        focus.wrappedValue = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
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

    private var intensityBinding: Binding<Double> {
        Binding(
            get: {
                haptic.intensity
            },
            set: { newValue in
                let intensity = newValue

                guard haptic.intensity != intensity else { return }
                haptic.intensity = intensity

                Task { @MainActor in
                    let msgToSend = PlatyMQTT.SendMessage(intensity * 10)
                    async let fut1 = try? mqttClient.publish(
                        to: .hapticLeft,
                        payload: msgToSend
                    )
                    async let fut2 = try? mqttClient.publish(
                        to: .hapticRight,
                        payload: msgToSend
                    )
                    let _ = await (fut1, fut2)
                }
            }
        )
    }
}

// MARK: - Shared

private struct DistanceSliderRow: View {
    @Binding var maximumDistance: Double?
    let accessibilityName: String
    private var language: AppLanguage { .current }

    // Half-meter steps through 20 m, followed by an unlimited endpoint.
    private let unlimitedEndpoint = 20.5

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { maximumDistance ?? unlimitedEndpoint },
            set: { maximumDistance = $0 >= unlimitedEndpoint ? nil : $0 }
        )
    }

    private var distanceDescription: String {
        if let maximumDistance {
            language.format("%.1f meters", maximumDistance)
        } else {
            language.localized("Unlimited")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: language.localized("Distance"))
                Spacer()
                Text(verbatim: distanceDescription)
                    .foregroundStyle(AppTheme.secondaryText)
                    .monospacedDigit()
            }
            .accessibilityHidden(true)

            Slider(value: sliderBinding, in: 0.5...unlimitedEndpoint, step: 0.5) {
                Text(verbatim: language.localized("Distance"))
            } minimumValueLabel: {
                Text("0.5")
                    .accessibilityHidden(true)
            } maximumValueLabel: {
                Text("∞")
                    .accessibilityHidden(true)
            }
            .foregroundStyle(AppTheme.secondaryText)
            .accessibilityLabel(Text(verbatim:
                "\(accessibilityName): \(language.localized("Distance"))"
            ))
            .accessibilityValue(Text(verbatim: distanceDescription))
            .accessibilityHint(Text(verbatim: language.localized(
                "Ignores detections beyond this distance. Move to the maximum for unlimited distance."
            )))
        }
        .padding(.vertical, 2)
    }
}

private struct CentralOnlyToggle: View {
    @Binding var isOn: Bool
    let accessibilityName: String
    private var language: AppLanguage { .current }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    language.localized("Central objects only"),
                    systemImage: "scope"
                )
                Text(verbatim: language.localized(
                    "Ignores objects outside the middle third of the view."
                ))
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .accessibilityLabel(Text(verbatim:
            "\(accessibilityName): \(language.localized("Central objects only"))"
        ))
    }
}

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
                .foregroundStyle(AppTheme.secondaryText)
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
            .foregroundStyle(AppTheme.secondaryText)
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
