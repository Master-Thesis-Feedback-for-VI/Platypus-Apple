//
//  PlatyDetection.swift
//  Platypus
//
//  Created by Yann Bernard on 04.10.26.
//

import Foundation
import SwiftUI

struct PlatyDetection {
    public var confidence: Float
    public var detectionType: PlatyDetectionType
    public var rect: CGRect

    let viewportSize: CGSize
}

extension PlatyDetection {
    // MARK: - Init

    static func from<Frame: PlatySize>(
        detection: Detection,
        frameSize: Frame,
        viewportSize: CGSize,
        imageTransform: CGAffineTransform,
        contentMode: ContentMode
    ) -> PlatyDetection? {
        guard
            let platyDetection = PlatyDetectionType.from(
                detectionType: detection.name
            )
        else { return nil }

        guard frameSize.pixelWidth > 0, frameSize.pixelHeight > 0,
            viewportSize.width > 0, viewportSize.height > 0
        else { return nil }

        let rect = Platypus.rect(
            for: detection.xyxy,
            imageSize: CGSize(
                width: frameSize.pixelWidth,
                height: frameSize.pixelHeight
            ),
            viewportSize: viewportSize,
            transform: imageTransform,
            contentMode: contentMode
        )

        return Self(
            confidence: detection.confidence,
            detectionType: platyDetection,
            rect: rect,
            viewportSize: viewportSize
        )
    }

    static func from<Frame: PlatySize>(
        detections: [Detection],
        frameSize: Frame,
        viewportSize: CGSize,
        imageTransform: CGAffineTransform,
        contentMode: ContentMode
    ) -> [PlatyDetection] {
        detections.compactMap { detection in
            PlatyDetection.from(
                detection: detection,
                frameSize: frameSize,
                viewportSize: viewportSize,
                imageTransform: imageTransform,
                contentMode: contentMode
            )
        }
    }

    static func from<Frame: PlatySize>(
        imageDetections: ImageDetections,
        frameSize: Frame,
        viewportSize: CGSize,
        imageTransform: CGAffineTransform,
        contentMode: ContentMode
    ) -> [PlatyDetection] {
        Self.from(
            detections: imageDetections.detections,
            frameSize: frameSize,
            viewportSize: viewportSize,
            imageTransform: imageTransform,
            contentMode: contentMode
        )
    }

    // MARK: - Math functions

    public func normVector() -> (Float, Float) {
        return (
            normalized(rect.midX, relativeTo: viewportSize.width / 2),
            normalized(rect.midY, relativeTo: viewportSize.height / 2)
        )
    }

    public func azimuth(_ horizontalFOV: Double = 65) -> Float {
        let x = Double(normVector().0)
        let halfFOV = horizontalFOV * .pi / 180 / 2

        let angle = atan(x * tan(halfFOV)) * 180 / .pi

        let wrapped = angle.truncatingRemainder(dividingBy: 360)
        return Float(wrapped < 0 ? wrapped + 360 : wrapped)
    }

    public func yFromCenter() -> (Float, Float) {
        return (
            normalized(rect.minY, relativeTo: viewportSize.height / 2),
            normalized(rect.maxY, relativeTo: viewportSize.height / 2)
        )
    }

    public func xFromCenter() -> (Float, Float) {
        return (
            normalized(rect.minX, relativeTo: viewportSize.width / 2),
            normalized(rect.maxX, relativeTo: viewportSize.width / 2)
        )
    }

    public func direction(_ horizontalFOV: Double = 65) -> Direction {
        let azi = azimuth(horizontalFOV)
        return Direction.closest(to: Double(azi))
    }
}  // End PlatyDetection extension

extension PlatyDetection: Equatable {}

enum PlatyDetectionType: String, Codable, CaseIterable, Identifiable {
    case car = "Car"
    case person = "Person"
    case bench = "Bench"
    case bicycle = "Bicycle"

    var id: Self { self }
    var key: String { "settings.detection.\(rawValue.lowercased())" }
}

extension PlatyDetectionType {
    static func from(detectionType: DetectionType) -> PlatyDetectionType? {
        let description = String(describing: detectionType).capitalized
        return PlatyDetectionType(rawValue: description)
    }
}

// MARK: - Utility functions

private func rect(
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
    let scale =
        contentMode == .fill
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

func normalized(_ point: CGFloat, relativeTo center: CGFloat)
    -> Float
{
    Float((point - center) / center).clamped(to: -1...1)
}

extension Float {
    fileprivate func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
