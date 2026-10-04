//
//  DetectionBoxOverlay.swift
//  Platypus
//
//  Created by Yann Bernard on 28.09.26.
//

import SwiftUI

struct DetectionBoxOverlay<Frame: PlatySize>: View {
    let detectedObjects: ImageDetections
    let frameSize: Frame
    let imageTransform: CGAffineTransform
    let contentMode: ContentMode

    var body: some View {
        GeometryReader { geo in
            if frameSize.pixelWidth > 0 && frameSize.pixelHeight > 0 {
                ForEach(detectedObjects.detections.indices, id: \.self) {
                    index in
                    let defDetection = detectedObjects.detections[index]
                    if let detection = PlatyDetection.from(
                        detection: defDetection,
                        frameSize: frameSize,
                        viewportSize: geo.size,
                        imageTransform: imageTransform,
                        contentMode: contentMode
                    ) {
                        Rectangle()
                            .path(in: detection.rect)
                            .stroke(Color.red, lineWidth: 2)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
