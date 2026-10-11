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
                        ZStack {
                            Rectangle()
                                .path(in: detection.rect)
                                .stroke(Color.red, lineWidth: 2)

                            Text(verbatim: AppLanguage.current.format("%.1f m", Double(detection.distance)))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    Color.red,
                                    in: RoundedRectangle(cornerRadius: 3)
                                )
                                .position(
                                    x: detection.rect.minX + 20,
                                    y: max(detection.rect.minY - 10, 10)
                                )
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
