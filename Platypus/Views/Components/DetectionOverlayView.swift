//
//  DetectionOverlayView.swift
//  Platypus
//

import SwiftUI

struct DetectionOverlayView<Frame: PlatySize>: View {
    let detectedObjects: ImageDetections
    let frameSize: Frame
    let imageTransform: CGAffineTransform
    let contentMode: ContentMode

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DetectionBoxOverlay(
                    detectedObjects: detectedObjects,
                    frameSize: frameSize,
                    imageTransform: imageTransform,
                    contentMode: contentMode
                )

                DetectionMQTTView(
                    detectedObjects: detectedObjects,
                    frameSize: frameSize,
                    viewportSize: geometry.size,
                    imageTransform: imageTransform,
                    contentMode: contentMode
                )
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
