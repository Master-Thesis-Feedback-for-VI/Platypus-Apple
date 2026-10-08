//
//  LiveviewModeView.swift
//  Platypus
//
//  Created by Yann Bernard on 12.09.26.
//

import SwiftUI
import os

struct LiveviewModeView: View {
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var locationRecorder: LocationRecorder
    @EnvironmentObject var imageRecognizerStore: ImageRecognizerStore

    var body: some View {
        Group {
            if cameraManager.isCamAuthorized {
                CameraActiveLiveView()
                    .environmentObject(cameraManager)
                    .environmentObject(imageRecognizerStore)
                    .environmentObject(locationRecorder)
            } else {
                VStack(spacing: 10) {
                    Text("Camera not authorized").font(.title2)
                    Text("Please go to Settings and allow camera access")
                }
            }

        }.task {
            assert(enableTracing(rustLog: .error))
        }
    }
}

struct CameraActiveLiveView: View {
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var locationRecorder: LocationRecorder
    @EnvironmentObject var imageRecognizerStore: ImageRecognizerStore

    @State private var logger = PlatyLogger(tag: "CameraActiveLiveView")
    @State private var isPreviewActive = false
    @State private var previewAttachTask: Task<Void, Never>? = nil
    @State private var locationSnapTask: Task<Void, Never>? = nil

    @State private var uniqueLocationTags = UniqueLocationTags(
        categories: [],
    )
    @State private var detectedObjects = ImageDetections(detections: [])
    @State private var progress: ProgressStatus = .switchedOff

    @State private var videoDimensions: CGSize = .zero
    @State private var detectionTransform: CGAffineTransform = .identity

    private let auth = AuthToHost(
        overpassUrl: infoValue("OVERPASS_URL"),
        nominatimUrl: infoValue("NOMINATIM_URL"),
        user: infoValue("USER_AGENT_NAME"),
        passwd: infoValue("PASSWORD"),
    )
    private let amountDominantColor: UInt32 = 4

    var body: some View {
        ZStack {
            CameraPreview(
                cameraManager: cameraManager,
                isActive: isPreviewActive
            )
            .ignoresSafeArea()

            DetectionOverlayView(
                detectedObjects: detectedObjects,
                uniqueLocationTags: uniqueLocationTags,
                frameSize: videoDimensions,
                imageTransform: detectionTransform,
                contentMode: .fill
            )

            ProgressIndicatorView(
                progress: progress,
                uniqueLocationTags: uniqueLocationTags,
                detectedObjects: detectedObjects
            )
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true

            isPreviewActive = false
            previewAttachTask?.cancel()
            previewAttachTask = Task { @MainActor in
                if !Task.isCancelled { isPreviewActive = true }
            }

            locationSnapTask?.cancel()
            locationSnapTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled { break }

                    logger.log("Recording image and location")
                    let start = ContinuousClock.now

                    progress = .hardware
                    guard let location = locationRecorder.location,
                        let img = try? await cameraManager.snapPhoto(),
                        let savedURL = try? await img.saveImage(
                            name: "image_taken"
                        )
                    else {
                        logger.log(
                            "Failed to record location or image",
                            level: .error
                        )
                        progress = .failure
                        continue
                    }

                    if let dimensions = img.pixelSize {
                        videoDimensions = dimensions
                        detectionTransform = img.detectionTransform
                    }

                    let cord = Coordinate(
                        lat: location.latitude,
                        lon: location.longitude
                    )
                    let imgPath = savedURL.path

                    guard let imgRecognizer = imageRecognizerStore.recognizer
                    else {
                        if let loadErr = imageRecognizerStore.loadError {
                            logger.log(
                                "Image recognizer not loaded or failed to load: \(loadErr)",
                                level: .error
                            )
                            progress = .failure
                            continue
                        } else {
                            logger.log(
                                "Still downloading models",
                                level: .warning
                            )
                            progress = .downloading
                            continue
                        }
                    }

                    progress = .evaluating
                    do {
                        let imageFlowData = try await imageFlowEvaluation(
                            location: cord,
                            auth: auth,
                            imgPath: imgPath,
                            imageRecognizer: imgRecognizer,
                            amount: amountDominantColor,
                        )

                        detectedObjects = imageFlowData.imageDetections()
                        uniqueLocationTags = imageFlowData.locationTags()

                        let elapsed =
                            (ContinuousClock.now - start) / .milliseconds(1)
                        let elapsed_formatted = String(format: "%.2f", elapsed)
                        logger.log(
                            "Evaluated to: \(uniqueLocationTags)"
                        )
                        logger.log(
                            "Evaluation took: \(elapsed_formatted) ms",
                            level: .debug
                        )

                        progress = .success
                    } catch {
                        logger.log(
                            "This failed due to \(error.localizedDescription)",
                            level: .error
                        )
                        progress = .failure
                    }
                }
            }

        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false

            previewAttachTask?.cancel()
            previewAttachTask = nil

            isPreviewActive = false

            locationSnapTask?.cancel()
            locationSnapTask = nil

            progress = .switchedOff
        }
    }
}

#Preview {
    LiveviewModeView()
}
