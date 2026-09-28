import SwiftUI

// Converts the detector's raw image pixels into the displayed image's coordinates.
enum DetectionBoxProjection {
    static func rect(
        for box: BoundingBox,
        imageSize: CGSize,
        viewportSize: CGSize,
        transform: CGAffineTransform,
        contentMode: ContentMode
    ) -> CGRect {
        let imageBounds = CGRect(origin: .zero, size: imageSize).applying(transform)
        let boxBounds = CGRect(
            x: CGFloat(box.x1),
            y: CGFloat(box.y1),
            width: CGFloat(box.x2 - box.x1),
            height: CGFloat(box.y2 - box.y1)
        ).applying(transform)

        let widthScale = viewportSize.width / imageBounds.width
        let heightScale = viewportSize.height / imageBounds.height
        let scale = contentMode == .fill
            ? max(widthScale, heightScale) : min(widthScale, heightScale)
        let offset = CGPoint(
            x: (viewportSize.width - imageBounds.width * scale) / 2,
            y: (viewportSize.height - imageBounds.height * scale) / 2
        )

        return CGRect(
            x: offset.x + (boxBounds.minX - imageBounds.minX) * scale,
            y: offset.y + (boxBounds.minY - imageBounds.minY) * scale,
            width: boxBounds.width * scale,
            height: boxBounds.height * scale
        )
    }
}
