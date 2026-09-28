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

    var body: some View {
        GeometryReader { geo in
            let scaleX = geo.size.width / CGFloat(frameSize.pixelWidth)
            let scaleY = geo.size.height / CGFloat(frameSize.pixelHeight)

            ForEach(detectedObjects.detections, id: \.self) { detection in
                let box = detection.xyxy
                let rect = CGRect(
                    x: CGFloat(box.x1) * scaleX,
                    y: CGFloat(box.y1) * scaleY,
                    width: CGFloat(box.x2 - box.x1) * scaleX,
                    height: CGFloat(box.y2 - box.y1) * scaleY
                )

                Rectangle()
                    .path(in: rect)
                    .stroke(Color.red, lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
    }
}
