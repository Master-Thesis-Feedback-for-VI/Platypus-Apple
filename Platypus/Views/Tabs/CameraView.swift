//
//  CameraView.swift
//  Platypus
//
//  Created by Assistant on 08.11.26.
//

import AVFoundation
import SwiftUI

struct CameraView: View {
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
                        RoundedRectangle(cornerRadius: 12)
                    )

                    Button {
                        if cameraManager.isRecording {
                            Task { await cameraManager.stopRecording() }
                        } else {
                            Task { await cameraManager.startRecording() }
                        }
                    } label: {
                        Label(
                            AppLanguage.current.localized(cameraManager.isRecording
                                ? "Stop Recording" : "Start Recording"),
                            systemImage: cameraManager.isRecording
                                ? "stop.circle.fill" : "record.circle"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HighContrastButtonStyle())

                    if let error = cameraManager.recordingError {
                        Text(verbatim: error.localizedDescription)
                            .font(.body)
                            .foregroundStyle(AppTheme.error)
                    }
                } else {
                    ContentUnavailableView(
                        AppLanguage.current.localized("Camera Access Needed"),
                        systemImage: "camera.fill",
                        description: Text(verbatim: AppLanguage.current.localized(
                            "Allow camera access in Settings to record video."
                        ))
                    )
                }
            }
            .padding()
            .navigationTitle(AppLanguage.current.localized("Camera"))
            .onAppear {
                isPreviewActive = false
                previewAttachTask?.cancel()
                previewAttachTask = Task { @MainActor in
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
