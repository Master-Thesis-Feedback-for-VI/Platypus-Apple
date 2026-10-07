//
//  DetectionMQTTView.swift
//  Platypus
//

import SwiftUI

struct DetectionMQTTView<Frame: PlatySize>: View {
    let detectedObjects: ImageDetections
    let uniqueLocationTag: UniqueLocationTags

    let frameSize: Frame
    let viewportSize: CGSize
    let imageTransform: CGAffineTransform
    let contentMode: ContentMode

    private let logger = PlatyLogger(tag: "DetectionMQTTView")
    @EnvironmentObject private var earconEngine: EarconPlayer
    @State private var tts = Speaker()
    @Environment(ProfileManager.self) private var profileManager

    @EnvironmentObject private var mqttClient: PlatyMQTT

    @Namespace private var namespace

    // MARK: - View

    var body: some View {
        let settings = PlatyLocationTag.from(uniqueLocationTags: uniqueLocationTag)
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

        let detectionsFiltered = detections.detections.filter {
            $0.name == .person || $0.name == .car
        }
        let detections = PlatyDetection.from(
            detections: detectionsFiltered,
            frameSize: frameSize,
            viewportSize: viewportSize,
            imageTransform: imageTransform,
            contentMode: contentMode
        )

        for detection in detections {
            guard !Task.isCancelled else { return }
            guard
                let setting = settings.detectionSettings[
                    detection.detectionType
                ]
            else {
                continue
            }

            // Haptic settings and callback
            let hapticSettings = setting.haptic
            if hapticSettings.switchedOn {
                let (left, right) = detection.xFromCenter()
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

            // Sound Settings and callback
            guard !Task.isCancelled else { return }
            switch setting.sound {
            case .off: break

            case .earcon(let earconSetting):
                do {
                    let volume = earconSetting.volume
                    let detectionType = detection.detectionType

                    await earconEngine.play(
                        detectionType,
                        volume: volume,
                        azimuth: Double(detection.azimuth())
                    )
                }

            case .tts(let ttsSetting):
                do {
                    let volume = ttsSetting.volume
                    var name = detection.detectionType.rawValue

                    if ttsSetting.enableDirectionControl {
                        let direction = String(
                            describing: detection.direction()
                        )
                        name = "\(name), \(direction)"
                    }

                    tts.speak(name, volume)
                }
            }
        }
    }

    // MARK: - Callbacks Sub

    private func swapProfile(msg: PlatyMQTT.RecMessage) {
        Task { @MainActor in
            logger.log("Received: \(msg)")

            switch msg.cmd {
            case .next: try? profileManager.next()
            case .prev: try? profileManager.prev()
            case .empty: return
            }
        }
    }
}

private struct HardwareInput: Equatable {
    let detectedObjects: ImageDetections
    let uniqueLocationTag: UniqueLocationTags
    let settings: ProfileManager.SettingsSnapshot?
}
