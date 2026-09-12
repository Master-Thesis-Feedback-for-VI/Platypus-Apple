//
//  CameraView.swift
//  Platypus
//
//  Created by Assistant on 08.11.26.
//

import AVFoundation
import SwiftUI

struct CameraView: View {
    @EnvironmentObject var locationViewModel: LocationRecorder
    @EnvironmentObject var cameraManager: CameraManager
    @State private var isPreviewActive = false
    @State private var previewAttachTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if cameraManager.isCamAuthorized {
                    CameraPreview(
                        cameraManager: cameraManager,
                        isActive: isPreviewActive
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(
                        RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    )

                    Button {
                        if cameraManager.isRecording {
                            Task { await cameraManager.stopRecording() }
                        } else {
                            Task { await cameraManager.startRecording() }
                        }
                    } label: {
                        Label(
                            cameraManager.isRecording
                                ? "Stop Recording" : "Start Recording",
                            systemImage: cameraManager.isRecording
                                ? "stop.circle.fill" : "record.circle"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(cameraManager.isRecording ? .red : .accentColor)

                    if let error = cameraManager.recordingError {
                        Text(error.localizedDescription)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } else {
                    ContentUnavailableView(
                        "Camera Access Needed",
                        systemImage: "camera.fill",
                        description: Text(
                            "Allow camera access in Settings to record video."
                        )
                    )
                }
            }
            .padding()
            .navigationTitle("Camera")
            .onAppear {
                isPreviewActive = false
                previewAttachTask?.cancel()
                previewAttachTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: Constants.contentionTime)
                    if !Task.isCancelled { isPreviewActive = true }
                }
            }
            .onDisappear {
                previewAttachTask?.cancel()
                previewAttachTask = nil
                isPreviewActive = false
            }
        }
    }
}

#Preview {
    CameraView()
}
