//
//  ProgressIndicatorView.swift
//  Platypus
//
//  Created by Yann Bernard on 24.09.26.
//

import SwiftUI

struct ProgressIndicatorView: View {
    let progress: ProgressStatus
    let uniqueLocationTags: UniqueLocationTags
    let detectedObjects: ImageDetections

    @EnvironmentObject private var mqttClient: PlatyMQTT

    private let logger = PlatyLogger(tag: "ProgressIndicatorView")

    var body: some View {
        VStack {
            ProgressCategoriesIndicator(progress: progress)
                .padding(.top, 15)

            Spacer()

            CategoryOverlayView(
                uniqueLocationTags: uniqueLocationTags,
                imageDetections: detectedObjects
            )
            .padding(.bottom, 24)
        }
        .onDisappear {
            mqttClient.stopLoop()
        }
        .task {
            do {
                logger.log("Connecting to mqtt server...")
                try await mqttClient.connect()
                logger.log("... Connected to mqtt server")

                mqttClient.addSubscription(
                    topic: "IoT/device/haptic_right"
                ) {
                    logger.log("IoT/device/haptic_right \($0)", level: .warning)
                }
                mqttClient.addSubscription(
                    topic: "IoT/device/haptic_left"
                ) {
                    logger.log(
                        "readwrite IoT/device/haptic_left: \($0)",
                        level: .warning
                    )
                }
                mqttClient.addSubscription(
                    topic: "IoT/device/profile_swap"
                ) {
                    logger.log(
                        "IoT/device/profile_swap: \($0)",
                        level: .warning
                    )
                }

                mqttClient.startLoop()
            } catch {
                logger.log("failed to connect: \(error)", level: .error)
            }
        }
    }
}
