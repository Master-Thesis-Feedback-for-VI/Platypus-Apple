//
//  LiveviewModeView.swift
//  Platypus
//
//  Created by Yann Bernard on 12.09.26.
//

import SwiftUI

struct LiveviewModeView: View {
    @EnvironmentObject var locationViewModel: LocationRecorder
    @EnvironmentObject var cameraManager: CameraManager

    var body: some View {
        NavigationStack {
            if cameraManager.isCamAuthorized {
                CameraActiveLiveView()
                    .environmentObject(locationViewModel)
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
    @EnvironmentObject var locationViewModel: LocationRecorder
    @EnvironmentObject var cameraManager: CameraManager

    @State private var isPreviewActive = false
    @State private var previewAttachTask: Task<Void, Never>? = nil

    var body: some View {
        VStack {
            CameraPreview(
                cameraManager: cameraManager,
                isActive: isPreviewActive
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        }
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

#Preview {
    LiveviewModeView()
}
