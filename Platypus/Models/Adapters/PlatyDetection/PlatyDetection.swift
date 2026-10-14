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
    public var distance: Float
    public var rect: CGRect

    let viewportSize: CGSize
}

extension PlatyDetection {
    // MARK: - Init

    init?<Frame: PlatySize>(
        detection: Detection,
        frameSize: Frame,
        viewportSize: CGSize,
        imageTransform: CGAffineTransform,
        contentMode: ContentMode
    ) {
        guard
            let platyDetection = PlatyDetectionType(
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

        self.confidence = detection.confidence
        self.detectionType = platyDetection
        self.distance = detection.distance
        self.rect = rect
        self.viewportSize = viewportSize
    }

    // MARK: - Math functions
    

    public func yFromCenter() -> (Double, Double) {
        return (
            normalized(rect.minY, relativeTo: viewportSize.height / 2),
            normalized(rect.maxY, relativeTo: viewportSize.height / 2)
        )
    }

    public func xFromCenter() -> (Double, Double) {
        return (
            normalized(rect.minX, relativeTo: viewportSize.width / 2),
            normalized(rect.maxX, relativeTo: viewportSize.width / 2)
        )
    }

    public func direction(_ horizontalFOV: Double = 65) -> Direction {
        let azi = azimuth(self, horizontalFOV)
        return Direction.closest(to: Double(azi))
    }
}  // End PlatyDetection extension

func azimuth(_ normalizable: some Normalizable, _ horizontalFOV: Double = 65) -> Float {
    let x = normalizable.normVector.x
    let halfFOV = horizontalFOV * .pi / 180 / 2

    let angle = atan(x * tan(halfFOV)) * 180 / .pi

    let wrapped = angle.truncatingRemainder(dividingBy: 360)
    return Float(wrapped < 0 ? wrapped + 360 : wrapped)
}

extension PlatyDetection: Equatable {}

enum PlatyDetectionType: String, Codable, CaseIterable, Identifiable {
    case car = "car"
    case person = "person"
    case bench = "bench"
    case bicycle = "bicycle"
    case cyclist = "cyclist"

    var id: Self { self }
    var key: String { "settings.detection.\(rawValue.lowercased())" }
}

extension PlatyDetectionType {
    init?(detectionType: DetectionType) {
        let description = String(describing: detectionType)
        if let platyType = PlatyDetectionType(rawValue: description) {
            self = platyType
        } else {
            return nil
        }
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
    -> Double
{
    Double((point - center) / center).clamped(to: -1...1)
}

extension Double {
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

protocol Normalizable {
    var normVector: CGPoint { get }
}

extension PlatyDetection: Normalizable {
    var normVector: CGPoint {
        let point = CGPoint(
            x: normalized(rect.midX, relativeTo: viewportSize.width / 2),
            y: normalized(rect.midY, relativeTo: viewportSize.height / 2)
        )
        return point
    }
}
