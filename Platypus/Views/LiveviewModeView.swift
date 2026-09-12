//
//  LiveviewModeView.swift
//  Platypus
//
//  Created by Yann Bernard on 12.09.26.
//

import SwiftUI

struct LiveviewModeView: View {
    @EnvironmentObject var cameraManager: CameraManager

    var body: some View {
        Group {
            if cameraManager.isCamAuthorized {
                CameraActiveLiveView()
                    .environmentObject(cameraManager)
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

    @State private var isPreviewActive = false
    @State private var previewAttachTask: Task<Void, Never>? = nil
    @State private var locationSnapTask: Task<Void, Never>? = nil
    
    @State private var locationRecorder = LocationRecorder()

    var body: some View {
        CameraPreview(
            cameraManager: cameraManager,
            isActive: isPreviewActive
        )
        .ignoresSafeArea()
        .onAppear {
            isPreviewActive = false
            previewAttachTask?.cancel()
            previewAttachTask = Task { @MainActor in
                if !Task.isCancelled { isPreviewActive = true }
            }
            
            locationSnapTask?.cancel()
            locationSnapTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    if Task.isCancelled { break }
                    guard let location = locationRecorder.location else {
                        continue
                    }
                    guard let img = try? await cameraManager.snapPhoto() else {
                        continue
                    }
                }
            }
            
            
        }
        .onDisappear {
            previewAttachTask?.cancel()
            previewAttachTask = nil
            isPreviewActive = false
        }
    }
}

#Preview {
    LiveviewModeView()
}
