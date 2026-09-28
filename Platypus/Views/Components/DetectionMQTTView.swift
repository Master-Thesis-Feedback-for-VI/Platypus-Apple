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

            for channel in [
                left < 0 ? AvailableTopics.hapticLeft : nil,
                right > 0 ? AvailableTopics.hapticRight : nil,
            ].compactMap({ $0 }) {
                do {
                    try await mqttClient.publish(
                        to: channel,
                        payload: .init(increaseDiff: 2)
                    )
                } catch {
                    logger.log("Could not send to \(channel.rawValue)", level: .error)
                }
            }
        }
    }
}
