//
//  CameraPreview.swift
//  Platypus
//
//  Created by Yann Bernard on 12.09.26.
//

import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
  let session: AVCaptureSession?

  func makeUIView(context: Context) -> PreviewView {
    let view = PreviewView()
    view.previewLayer.session = session
    return view
  }

  func updateUIView(_ uiView: PreviewView, context: Context) {
    uiView.previewLayer.session = session
  }

  static func dismantleUIView(_ uiView: PreviewView, coordinator: ()) {
    uiView.previewLayer.session = nil
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
