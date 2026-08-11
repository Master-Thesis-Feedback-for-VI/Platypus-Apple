//
//  CameraView.swift
//  Platypus
//
//  Created by Assistant on 08.11.26.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var locationViewModel = LocationViewModel()
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if cameraManager.isCamAuthorized {
                    CameraPreview(session: cameraManager.session)
                        .frame(maxWidth: .infinity)
                        .frame(height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Button {
                        if cameraManager.isRecording {
                            cameraManager.stopRecording()
                        } else {
                            cameraManager.startRecording()
                        }
                    } label: {
                        Label(
                            cameraManager.isRecording ? "Stop Recording" : "Start Recording",
                            systemImage: cameraManager.isRecording ? "stop.circle.fill" : "record.circle"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(cameraManager.isRecording ? .red : .accentColor)

                    if let url = cameraManager.capturedVideoURL {
                        Text("Saved to: \(url.lastPathComponent)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let error = cameraManager.recordingError {
                        Text(error.localizedDescription)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } else {
                    ContentUnavailableView(
                        "Camera Access Needed",
                        systemImage: "camera.fill",
                        description: Text("Allow camera access in Settings to record video.")
                    )
                }
                
                HStack(spacing: 16) {
                    if let loc = locationViewModel.location {
                        Text("Latitude: \(loc.latitude)").foregroundStyle(.secondary)
                        Text("Longitude: \(loc.longitude)").foregroundStyle(.secondary)
                    } else {
                        Text("Error could not fetch coords")
                    }
                }.padding()
            }
            .padding()
            .navigationTitle("Camera")
            .onAppear {
                cameraManager.startSession()
            }
            .onDisappear {
                if cameraManager.isRecording {
                    cameraManager.stopRecording()
                }
                cameraManager.stopSession()
            }
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer")
        }
        layer.videoGravity = .resizeAspectFill
        return layer
    }
}

#Preview {
    CameraView()
}
