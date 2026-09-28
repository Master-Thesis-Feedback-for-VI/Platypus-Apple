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
                    let box = detectedObjects.detections[index].xyxy
                    let rect = DetectionBoxProjection.rect(
                        for: box,
                        imageSize: CGSize(
                            width: frameSize.pixelWidth,
                            height: frameSize.pixelHeight
                        ),
                        viewportSize: geo.size,
                        transform: imageTransform,
                        contentMode: contentMode
                    )

                    Rectangle()
                        .path(in: rect)
                        .stroke(Color.red, lineWidth: 2)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
