//
//  DetectionOverlayView.swift
//  Platypus
//

import SwiftUI

struct DetectionOverlayView<Frame: PlatySize>: View {
    let detectedObjects: ImageDetections
    let uniqueLocationTags: UniqueLocationTags
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

                DetectionCallbackView(
                    detectedObjects: detectedObjects,
                    uniqueLocationTag: uniqueLocationTags,
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
