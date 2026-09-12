//
//  CameraPreview.swift
//  Platypus
//
//  Created by Yann Bernard on 12.09.26.
//

import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
  let cameraManager: CameraManager
  let isActive: Bool

  final class Coordinator {
    var pendingTask: Task<Void, Never>?
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> PreviewView {
    PreviewView()
  }

  func updateUIView(_ uiView: PreviewView, context: Context) {
    let layer = uiView.previewLayer
    let manager = cameraManager
    let active = isActive

    context.coordinator.pendingTask?.cancel()
    context.coordinator.pendingTask = Task {
      if active {
        await manager.attachPreview(layer)
      } else {
        await manager.detachPreview(layer)
      }
    }
  }

  static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
    coordinator.pendingTask?.cancel()
  }
}

final class PreviewView: UIView {
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
