//
//  DetectionMQTTView.swift
//  Platypus
//

import SwiftUI

struct DetectionCallbackView<Frame: PlatySize>: View {
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
            }
            .onAppear {
                let topic = AvailableTopics.profileSwap
                mqttClient.addCallback(
                    topic: topic,
                    namespace: namespace,
                    cb: swapProfile
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

        var filteredDetections = detections
        // TODO Fix the issue where only one detction passes instead there we should loop over evry type and the deciee waht we do with
        // each type currently we will never group anything
        if let minVal = detections.closestDetection {
            filteredDetections = PlatyDetections(detection: minVal)
        }

        // Maybe some kind of grouping would make sense ie TTS: 3 Persons front avergae 3 meters
        // TODO: This
        //        for detType in PlatyDetectionType.allCases {
        //            guard !Task.isCancelled else { return }
        //
        //            let detectionsInCat = PlatyGroupedDetections(
        //                from: detections,
        //                on: detType
        //            )
        //            guard
        //                let setting = settings.detectionSettings[
        //                    detType
        //                ]
        //            else {
        //                continue
        //            }
        //
        //            var selectedGroup: SelectedGrouped? = nil
        //            if setting.groupFeedback {
        //                selectedGroup = initSelectedGroup(
        //                    detections: detectionsInCat.inner,
        //                    detectionType: detType
        //                )
        //            }
        //        }

        for detection in filteredDetections.inner {
            guard !Task.isCancelled else { return }
            guard
                let setting = settings.detectionSettings[
                    detection.detectionType
                ]
            else {
                continue
            }

            let selectedGroup: SelectedGrouped? =
                if setting.groupFeedback {
                    initSelectedGroup(
                        detections: filteredDetections,
                        detectionType: detection.detectionType
                    )
                } else { nil }

            // Haptic settings and callback
            let hapticSettings = setting.haptic
            async let hapticFeedbackFut = hapticFeedbackReact(
                hapticSettings,
                detection,
                selectedGroup: selectedGroup
            )

            // Sound Settings and callback
            guard !Task.isCancelled else { return }
            let handle = Task {
                let soundSettings = setting.sound
                switch soundSettings {
                case .off: break
                case .earcon(let earconSetting):
                    await earconFeedbackReact(
                        earconSetting: earconSetting,
                        detection: detection,
                        selectedGroup: selectedGroup
                    )
                case .tts(let ttsSetting):
                    ttsFeedbackReact(
                        ttsSetting: ttsSetting,
                        detection: detection,
                        selectedGroup: selectedGroup
                    )
                }
            }
            
            let _ = await (handle, hapticFeedbackFut)
        }
    }

    private func hapticFeedbackReact(
        _ hapticSettings: HapticSettings,
        _ detection: PlatyDetection,
        selectedGroup: SelectedGrouped?
    ) async {
        guard hapticSettings.switchedOn else { return }

        var bound: (Double, Double)
        if let selectedGroup {
            bound = selectedGroup.xFromCenter
        } else {
            bound = detection.xFromCenter()
        }
        let (left, right) = bound

        let candidates = [
            (Double(left), AvailableTopics.hapticLeft, left < 0),
            (Double(right), AvailableTopics.hapticRight, right > 0),
        ]
        let hapticSignals: [(AvailableTopics, Int)] =
            candidates.compactMap { value, topic, shouldSend in
                let signalStrength = Int(
                    (abs(value) * 10.0 * hapticSettings.intensity)
                        .rounded()
                )

                return shouldSend ? (topic, signalStrength) : nil
            }

        for (channel, scale) in hapticSignals {
            do {
                try await mqttClient.publish(
                    to: channel,
                    payload: .init(increaseDiff: scale)
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
        detection: PlatyDetection,
        selectedGroup: SelectedGrouped?
    ) async {
        let volume = earconSetting.volume
        let detectionType = detection.detectionType

        let playedDirection: any Normalizable
        if let selectedGroup {
            playedDirection = selectedGroup
        } else {
            playedDirection = detection
        }

        await earconEngine.play(
            detectionType,
            volume: volume,
            azimuth: earconAzimuth(for: playedDirection)
        )
    }

    private func ttsFeedbackReact(
        ttsSetting: TtsSetting,
        detection: PlatyDetection,
        selectedGroup: SelectedGrouped?
    ) {
        let volume = ttsSetting.volume
        let language = AppLanguage.current
        var name = language.localized(
            detection.detectionType.rawValue
        )
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
                switchableDirection = detection.direction(
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
            let distance = language.format(
                "%.1f meters",
                detection.distance
            )
            name += ", \(distance)"
        }

        tts.speak(name, volume)
    }

    // MARK: - Callbacks Sub

    private func swapProfile(msg: PlatyMQTT.RecMessage) {
        Task { @MainActor in
            logger.log("Received: \(msg)")

            switch msg.cmd {
            case .next:
                try? profileManager.next(earconEngine)
            case .prev:
                try? profileManager.prev(earconEngine)
            case .empty: return
            }
        }
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
        return groupedDetections.groupedSelection(3)
    }
}

private struct HardwareInput: Equatable {
    let detectedObjects: ImageDetections
    let uniqueLocationTag: UniqueLocationTags
    let settings: ProfileManager.SettingsSnapshot?
}
