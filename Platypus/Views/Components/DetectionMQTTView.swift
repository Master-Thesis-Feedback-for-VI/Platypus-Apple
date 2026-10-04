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

    @EnvironmentObject private var mqttClient: PlatyMQTT

    @Environment(\.modelContext) private var ctx
    @Query(
        filter: #Predicate<ProfileSettings> { $0.deletedAt == nil },
        sort: \ProfileSettings.created,
    )
    private var profiles: [ProfileSettings]
    private var currentProfile: ProfileSettings {
        let activeProfiles = profiles.filter({ $0.isActive })
        precondition(activeProfiles.count == 1)
        return activeProfiles.first!
    }

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
        let currentSettingsSet = currentProfile.settings[locationTag]!

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
                        shouldSend
                            ? (
                                topic,
                                Int(
                                    (abs(value) * 10 * hapticSettings.intensity)
                                        .rounded()
                                )
                            ) : nil
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
            if setting.sound.soundVariant != .off {

            }
        }
    }

    // MARK: - Callbacks Sub

    private func swapProfile(msg: PlatyMQTT.RecMessage) {
        Task { @MainActor in
            logger.log("Received: \(msg)")

            guard profiles.count > 1,
                let currentIdx = profiles.firstIndex(where: {
                    $0.isActive
                })
            else { return }

            let target: Int
            switch msg.cmd {
            case .next: target = (currentIdx + 1) % profiles.count
            case .prev:
                target =
                    (currentIdx - 1 + profiles.count)
                    % profiles.count
            case .empty: return
            }

            profiles[currentIdx].isActive = false
            profiles[target].isActive = true
            try? ctx.save()
        }
    }
}

private struct HardwareInput: Equatable {
    let detectedObjects: ImageDetections
    let uniqueLocationTag: UniqueLocationTags
}
