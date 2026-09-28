//
//  ProgressIndicatorView.swift
//  Platypus
//
//  Created by Yann Bernard on 24.09.26.
//

import AVFoundation
import SwiftUI

struct ProgressIndicatorView<Frame: PlatySize>: View {
    let progress: ProgressStatus
    let uniqueLocationTags: UniqueLocationTags
    let detectedObjects: ImageDetections
    let frameSize: Frame

    @EnvironmentObject private var mqttClient: PlatyMQTT

    private let logger = PlatyLogger(tag: "ProgressIndicatorView")

    var body: some View {
        VStack {
//            DetectionBoxOverlay(detectedObjects: detectedObjects, frameSize: frameSize)
            
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
        .onChange(of: detectedObjects) { _oldValue, newValue in
            // Example this should be replaced with profiles
            Task {
                let locationTag = uniqueLocationTags.categories

                let persons = detectedObjects.fetch(.person)
                if persons.count > 0
                {
                    for person in persons {
                        
                        let (xLeftBbox, xRightBbox) = person.xFromCenter(
                            frameSize
                        )
                        if xLeftBbox < 0 {
                            let channel = AvailableTopics.hapticLeft
                            do {
                                try await mqttClient.publish(
                                    to: channel,
                                    payload: .init(increaseDiff: 2)
                                )
                            } catch {
                                logger.log("Could not send to \(channel.rawValue)", level: .error)
                            }
                        }
                        if xRightBbox > 0 {
                            let channel = AvailableTopics.hapticLeft
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
                } else if locationTag.contains(.outside) {

                }
            }
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
}

func naturalVideoSize(for asset: AVAsset) async throws -> CGSize {
    let tracks = try await asset.loadTracks(withMediaType: .video)
    guard let track = tracks.first else { return .zero }
    let size = try await track.load(.naturalSize)
    let transform = try await track.load(.preferredTransform)
    let transformed = size.applying(transform)
    return CGSize(
        width: abs(transformed.width),
        height: abs(transformed.height)
    )
}
