//
//  DetectionMQTTView.swift
//  Platypus
//

import SwiftUI

struct DetectionMQTTView<Frame: PlatySize>: View {
    let detectedObjects: ImageDetections
    let frameSize: Frame
    let viewportSize: CGSize
    let imageTransform: CGAffineTransform
    let contentMode: ContentMode

    @EnvironmentObject private var mqttClient: PlatyMQTT

    private let logger = PlatyLogger(tag: "DetectionMQTTView")

    var body: some View {
        Color.clear
            .onChange(of: detectedObjects) { _, newValue in
                Task {
                    await publishHaptics(for: newValue)
                }
            }
            .onAppear {
                let topic = AvailableTopics.profileSwap
                mqttClient.addCallback(topic: topic) {
                    logger.log("\(topic.rawValue) \($0)", level: .warning)
                }
            }
            .onDisappear {
                mqttClient.flushCallbacks()
            }
    }

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
}
