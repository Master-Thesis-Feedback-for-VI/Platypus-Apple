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
                    if let detection = PlatyDetection(
                        detection: defDetection,
                        frameSize: frameSize,
                        viewportSize: geo.size,
                        imageTransform: imageTransform,
                        contentMode: contentMode
                    ) {
                        ZStack {
                            Rectangle()
                                .path(in: detection.rect)
                                .stroke(AppTheme.background, lineWidth: 6)
                            Rectangle()
                                .path(in: detection.rect)
                                .stroke(AppTheme.text, lineWidth: 3)

                            Text(verbatim: AppLanguage.current.format("%.1f m", Double(detection.distance)))
                                .font(.body.monospacedDigit().bold())
                                .foregroundStyle(AppTheme.text)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    AppTheme.background,
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
