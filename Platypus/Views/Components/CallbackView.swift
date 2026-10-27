//
//  DetectionMQTTView.swift
//  Platypus
//

import SwiftUI

struct CallbackView<Frame: PlatySize>: View {
    let detectedObjects: ImageDetections
    let uniqueLocationTag: UniqueLocationTags

    let frameSize: Frame
    let viewportSize: CGSize
    let imageTransform: CGAffineTransform
    let contentMode: ContentMode

    private let logger = PlatyLogger(tag: "DetectionMQTTView")

    @State private var tts = Speaker()

    @Environment(ProfileManager.self) private var profileManager

    @EnvironmentObject private var mqttClient: PlatyMQTT
    @EnvironmentObject private var earconEngine: EarconPlayer

    @Namespace private var namespace
    @State private var lastHapticFeedback: ContinuousClock.Instant?

    // MARK: - View

    var body: some View {
        let settings = PlatyLocationTag.from(
            uniqueLocationTags: uniqueLocationTag
        )
        .flatMap { profileManager.settings(for: $0) }

        Color.clear
            .task(
                id: HardwareInput(
                    detectedObjects: detectedObjects,
                    uniqueLocationTag: uniqueLocationTag,
                    settings: settings
                )
            ) {
                await onSituationChange(
                    for: detectedObjects,
                    settings: settings?.settings
                )
                try? await mqttClient.publish(
                    to: .telemetryReport,
                    payload: uniqueLocationTag
                )
            }
            .onAppear {
                let topic = AvailableTopics.profileSwap
                let cb: (PlatyMQTT.RecMessage) -> Void = { msg in
                    logger.log("Received msg: \(msg)")
                    ProfileManager.swapProfile(
                        msg: msg,
                        pm: profileManager
                    )
                }

                mqttClient.addCallback(
                    topic: topic,
                    namespace: namespace,
                    cb: cb
                )
            }
            .onDisappear {
                mqttClient.flushCallbacks(namespace: namespace)
            }
    }

    // MARK: - Callbacks Pub

    private func onSituationChange(
        for detections: ImageDetections,
        settings: ProfileSingularSettings?
    ) async {
        guard frameSize.pixelWidth > 0, frameSize.pixelHeight > 0,
            viewportSize.width > 0, viewportSize.height > 0
        else { return }
        guard let settings else { return }

        let detectionsFiltered: [Detection] = detections.detections.filter {
            detection in
            PlatyDetectionType.allCases.contains { element in
                let detType = PlatyDetectionType(detectionType: detection.name)
                return detType != nil
            }
        }

        let detections = PlatyDetections(
            detections: detectionsFiltered,
            frameSize: frameSize,
            viewportSize: viewportSize,
            imageTransform: imageTransform,
            contentMode: contentMode
        )

        async let soundFeedback: Void = feedbackReact(
            detections: detections,
            settings: settings,
            channel: .sound
        )
        async let hapticFeedback: Void = feedbackReact(
            detections: detections,
            settings: settings,
            channel: .haptic
        )
        async let telemetryDetection = try? mqttClient.publish(
            to: .telemetryReport,
            payload: detections
        )

        let _ = await (soundFeedback, hapticFeedback, telemetryDetection)
    }

    private func feedbackReact(
        detections: PlatyDetections,
        settings: ProfileSingularSettings,
        channel: FeedbackChannel
    ) async {
        let detections = detections.filteredForFeedback(
            settings: settings.detectionSettings,
            channel: channel
        )

        guard !Task.isCancelled else { return }
        guard !detections.inner.isEmpty else {
            if case .haptic = channel { await flushHapticFeedback() }
            return
        }
        let closestCategory = detections.closestDetection!
        let detType = closestCategory.detectionType
        let detectionsInCat = PlatyGroupedDetections(
            from: detections,
            on: detType
        )
        guard
            let setting = settings.detectionSettings[
                detType
            ], !detectionsInCat.isEmpty
        else {
            if case .haptic = channel { await flushHapticFeedback() }
            return
        }

        let selectedGroup: SelectedGrouped? =
            if setting.groupFeedback {
                initSelectedGroup(
                    detections: detectionsInCat.inner,
                    detectionType: detType
                )
            } else { nil }

        switch channel {
        case .haptic:
            await hapticFeedbackReact(
                hapticSettings: setting.haptic,
                groupedDetection: detectionsInCat,
                selectedGroup: selectedGroup
            )
        case .sound:
            let soundSettings = setting.sound
            switch soundSettings {
            case .off: break
            case .earcon(let earconSetting):
                await earconFeedbackReact(
                    earconSetting: earconSetting,
                    groupedDetection: detectionsInCat,
                    selectedGroup: selectedGroup
                )
            case .tts(let ttsSetting):
                ttsFeedbackReact(
                    ttsSetting: ttsSetting,
                    groupedDetection: detectionsInCat,
                    selectedGroup: selectedGroup
                )
            }
        }

    }

    private func flushHapticFeedback() async {
        guard !Task.isCancelled,
            let lastHapticFeedback,
            ContinuousClock.now - lastHapticFeedback >= .milliseconds(500)
        else { return }

        self.lastHapticFeedback = nil

        let flushMsg = PlatyMQTT.SendMessage(0)
        async let pub1 = try? mqttClient.publish(
            to: AvailableTopics.hapticLeft,
            payload: flushMsg
        )

        async let pub2 = try? mqttClient.publish(
            to: AvailableTopics.hapticRight,
            payload: flushMsg
        )

        let _ = await (pub1, pub2)
    }

    private func hapticFeedbackReact(
        hapticSettings: HapticSettings,
        groupedDetection: PlatyGroupedDetections,
        selectedGroup: SelectedGrouped?
    ) async {
        guard !Task.isCancelled else { return }
        guard hapticSettings.switchedOn, !groupedDetection.isEmpty else {
            await flushHapticFeedback()
            return
        }

        var bound: (Double, Double)
        if let selectedGroup {
            bound = selectedGroup.xFromCenter
        } else {
            let detection = groupedDetection.closestDetection!
            bound = detection.xFromCenter()
        }
        let (left, right) = bound

        let hapticSignals =
            [
                (max(-left, 0), AvailableTopics.hapticLeft),
                (max(right, 0), AvailableTopics.hapticRight),
            ].map { value, topic in
                let signalStrength = max(
                    Int(
                        (value * 10.0 * hapticSettings.intensity)
                            .rounded()
                    ),
                    0
                )

                return (topic, PlatyMQTT.SendMessage(signalStrength))
            }

        lastHapticFeedback = ContinuousClock.now

        for (channel, msg) in hapticSignals {
            do {
                try await mqttClient.publish(
                    to: channel,
                    payload: msg
                )
            } catch {
                logger.log(
                    "Could not send to \(channel.rawValue)",
                    level: .error
                )
            }
        }
    }

    private func earconFeedbackReact(
        earconSetting: EarconSetting,
        groupedDetection: PlatyGroupedDetections,
        selectedGroup: SelectedGrouped?
    ) async {
        guard !groupedDetection.isEmpty else { return }

        let volume = earconSetting.volume

        let playedDirection: any Normalizable
        if let selectedGroup {
            playedDirection = selectedGroup
        } else {
            let detection = groupedDetection.closestDetection!
            playedDirection = detection
        }

        await earconEngine.play(
            groupedDetection.containedType,
            volume: volume,
            azimuth: earconAzimuth(for: playedDirection)
        )
    }

    private func ttsFeedbackReact(
        ttsSetting: TtsSetting,
        groupedDetection: PlatyGroupedDetections,
        selectedGroup: SelectedGrouped?
    ) {
        guard !groupedDetection.isEmpty else { return }
        let detection: PlatyDetection? =
            if selectedGroup != nil {
                nil
            } else {
                groupedDetection.closestDetection
            }

        let volume = ttsSetting.volume
        let language = AppLanguage.current

        var name = groupedDetection.containedType.localizedName(in: language)
        if let selectedGroup {
            name = "\(selectedGroup.detections.inner.count) \(name)"
        }

        if ttsSetting.enableDirectionControl {
            let horizontalFOV = 65.0
            let switchableDirection: Direction
            if let selectedGroup {
                let azi = azimuth(selectedGroup, horizontalFOV)
                switchableDirection = Direction.closest(
                    to: Double(azi)
                )
            } else {
                switchableDirection = detection!.direction(
                    horizontalFOV
                )
            }

            let direction: Direction?
            switch switchableDirection {
            case .front: direction = .front
            case .frontLeft, .frontLeftLeft, .frontFrontLeft, .left:
                direction = .left
            case .frontRight, .frontRightRight, .frontFrontRight,
                .right:
                direction = .right
            default:
                direction = nil
            }

            if let direction {
                let describedDirection = String(
                    describing: direction
                )
                name +=
                    ", \(language.localized(describedDirection))"
            }
        }

        if ttsSetting.enableDistanceEstimation {
            let distance =
                if let selectedGroup {
                    selectedGroup.distance
                } else {
                    Double(detection!.distance)
                }

            let formatedDistance = language.format(
                "%.1f meters",
                distance
            )
            name += ", \(formatedDistance)"
        }

        tts.speak(name, volume, speed: ttsSetting.speed)
    }

    // MARK: - Utils

    private func earconAzimuth(for normalizable: some Normalizable) -> Double {
        let x = normalizable.normVector.x
        // Spread the visible width across wider sound angles; boost positions
        // near the center so left and right are easier to distinguish.
        return (x < 0 ? -1 : 1) * 90 * pow(abs(x), 0.45)
    }

    private func initSelectedGroup(
        detections: PlatyDetections,
        detectionType: PlatyDetectionType
    ) -> SelectedGrouped? {
        let groupedDetections = PlatyGroupedDetections(
            from: detections,
            on: detectionType
        )
        return groupedDetections.groupedSelection(meters: 2)
    }
}

private struct HardwareInput: Equatable {
    let detectedObjects: ImageDetections
    let uniqueLocationTag: UniqueLocationTags
    let settings: ProfileManager.SettingsSnapshot?
}
