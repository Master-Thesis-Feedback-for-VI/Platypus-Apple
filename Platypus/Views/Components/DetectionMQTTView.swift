//
//  DetectionMQTTView.swift
//  Platypus
//

import SwiftData
import SwiftUI

struct DetectionMQTTView<Frame: PlatySize>: View {
    let detectedObjects: ImageDetections
    let uniqueLocationTag: UniqueLocationTags

    let frameSize: Frame
    let viewportSize: CGSize
    let imageTransform: CGAffineTransform
    let contentMode: ContentMode

    private let logger = PlatyLogger(tag: "DetectionMQTTView")
    private let tts = Speaker()
    @State private var profileManager: ProfileManager?

    @EnvironmentObject private var mqttClient: PlatyMQTT
    @EnvironmentObject private var earconEngine: EarconPlayer

    @Environment(\.modelContext) private var ctx
    @Namespace private var namespace

    // MARK: - View

    var body: some View {
        Color.clear
            .task(
                id: HardwareInput(
                    detectedObjects: detectedObjects,
                    uniqueLocationTag: uniqueLocationTag
                )
            ) {
                await publishHaptics(
                    for: detectedObjects,
                    location: uniqueLocationTag
                )
            }
            .task {
                profileManager = ProfileManager(context: ctx)
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

    private func publishHaptics(
        for detections: ImageDetections,
        location: UniqueLocationTags
    ) async {
        guard frameSize.pixelWidth > 0, frameSize.pixelHeight > 0,
            viewportSize.width > 0, viewportSize.height > 0
        else { return }

        // TODO: Finish
        guard
            let locationTag = PlatyLocationTag.from(
                uniqueLocationTags: location
            )
        else { return }
        guard let profileManager else { return }

        let currentSettingsSet = profileManager.currentProfile.settings[
            locationTag
        ]!

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
            guard
                let setting = currentSettingsSet.detectionSettings[
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
            switch setting.sound {
            case .off: break

            case .earcon(let earconSetting):
                do {
                    let volume = earconSetting.volume
                    let detectionType = detection.detectionType

                    earconEngine.play(
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
            case .next: try? profileManager?.next()
            case .prev: try? profileManager?.prev()
            case .empty: return
            }
        }
    }
}

private struct HardwareInput: Equatable {
    let detectedObjects: ImageDetections
    let uniqueLocationTag: UniqueLocationTags
}
