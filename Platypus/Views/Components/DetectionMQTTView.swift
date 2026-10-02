//
//  DetectionMQTTView.swift
//  Platypus
//

import SwiftData
import SwiftUI

struct DetectionMQTTView<Frame: PlatySize>: View {
    let detectedObjects: ImageDetections
    let frameSize: Frame
    let viewportSize: CGSize
    let imageTransform: CGAffineTransform
    let contentMode: ContentMode

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

    private let logger = PlatyLogger(tag: "DetectionMQTTView")

    // MARK: - View

    var body: some View {
        Color.clear
            .onChange(of: detectedObjects) { _, newValue in
                Task {
                    await publishHaptics(for: newValue)
                }
            }
            .onAppear {
                let topic = AvailableTopics.profileSwap
                mqttClient.addCallback(topic: topic, cb: swapProfile)
            }
            .onDisappear {
                mqttClient.flushCallbacks()
            }
    }

    // MARK: - Callbacks Pub

    private func publishHaptics(for detections: ImageDetections) async {
        guard frameSize.pixelWidth > 0, frameSize.pixelHeight > 0,
            viewportSize.width > 0, viewportSize.height > 0
        else { return }

        for person in detections.fetch(.person) {
            let (left, right) = person.xFromCenter(
                frameSize,
                in: viewportSize,
                transform: imageTransform,
                contentMode: contentMode
            )

            let hapticSignals: [(AvailableTopics, Int)] = [
                (left, AvailableTopics.hapticLeft, left < 0),
                (right, AvailableTopics.hapticRight, right > 0),
            ].compactMap { value, topic, shouldSend in
                shouldSend ? (topic, Int((abs(value) * 10).rounded())) : nil
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
