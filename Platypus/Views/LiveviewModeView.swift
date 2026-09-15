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

    @State private var categoriesDetected: [ContextCategory] = []
    @State private var progress: ProgressStatus = .switchedOff

    var body: some View {
        ZStack {
            CameraPreview(
                cameraManager: cameraManager,
                isActive: isPreviewActive
            )
            .ignoresSafeArea()

            VStack {
                ProgressCategoriesIndicator(progress: progress)
                    .padding(.top, 15)
                
                Spacer()
                
                CategoryOverlayView(categories: categoriesDetected)
                    .padding(.bottom, 24)
            }
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

                    let cord = Coordinate(
                        lat: location.latitude,
                        lon: location.longitude
                    )
                    let imgPath = savedURL.path

                    guard let imgRecognizer = imageRecognizerStore.recognizer
                    else {
                        logger.log(
                            "Image recognizer not loaded or failed to load",
                            level: .error
                        )
                        progress = .failure
                        continue
                    }

                    progress = .evaluating
                    do {
                        let evaluations = try await evaluateContext(
                            location: cord,
                            frame: imgPath,
                            imageModel: imgRecognizer
                        )
                        categoriesDetected = evaluations
                        progress = .success

                        let elapsed =
                            (ContinuousClock.now - start) / .milliseconds(1)
                        let elapsed_formatted = String(format: "%.2f", elapsed)
                        logger.log("Evaluated to: \(evaluations)")
                        logger.log(
                            "Evaluation took: \(elapsed_formatted) ms",
                            level: .debug
                        )
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
