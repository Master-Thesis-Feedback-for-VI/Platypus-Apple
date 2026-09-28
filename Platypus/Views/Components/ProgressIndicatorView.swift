//
//  ProgressIndicatorView.swift
//  Platypus
//
//  Created by Yann Bernard on 24.09.26.
//

import SwiftUI

struct ProgressIndicatorView<Frame: PlatySize>: View {
    let progress: ProgressStatus
    let uniqueLocationTags: UniqueLocationTags
    let detectedObjects: ImageDetections
    let frameSize: Frame
    var imageTransform: CGAffineTransform = .identity
    var contentMode: ContentMode = .fill

    @EnvironmentObject private var mqttClient: PlatyMQTT

    private let logger = PlatyLogger(tag: "ProgressIndicatorView")

    var body: some View {
        VStack {
            ProgressCategoriesIndicator(progress: progress)
                .padding(.top, 15)
            Text("\(frameSize.pixelWidth)x\(frameSize.pixelHeight)")

            Spacer()

            CategoryOverlayView(
                uniqueLocationTags: uniqueLocationTags,
                imageDetections: detectedObjects
            )
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            GeometryReader { geometry in
                DetectionBoxOverlay(
                    detectedObjects: detectedObjects,
                    frameSize: frameSize,
                    imageTransform: imageTransform,
                    contentMode: contentMode
                )
                .onChange(of: detectedObjects) { _, newValue in
                    Task {
                        await handleDetections(
                            newValue,
                            viewportSize: geometry.size
                        )
                    }
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            let topic = AvailableTopics.profileSwap
            mqttClient.addCallback(topic: topic) {
                logger.log(
                    "\(topic.rawValue) \($0)",
                    level: .warning
                )
            }
        }
        .onDisappear {
            mqttClient.flushCallbacks()
        }
    }

    private func handleDetections(
        _ detections: ImageDetections,
        viewportSize: CGSize
    ) async {
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

            // A box crossing the center activates both sides.
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
                    logger.log(
                        "Could not send to \(channel.rawValue)",
                        level: .error
                    )
                }
            }
        }
    }
}
