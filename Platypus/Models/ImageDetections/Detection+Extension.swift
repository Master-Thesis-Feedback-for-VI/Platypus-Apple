//
//  Detection+Extension.swift
//  Platypus
//
//  Created by Yann Bernard on 26.09.26.
//

import SwiftUI

extension Detection {
    // Normalized display positions: -1 is left/top, +1 is right/bottom.
    // The returned edges are ordered left-to-right and top-to-bottom even for rotated images.
    public func xFromCenter(
        _ size: borrowing some PlatySize,
        in viewportSize: CGSize,
        transform: CGAffineTransform = .identity,
        contentMode: ContentMode = .fill
    ) -> (Float, Float) {
        guard
            let rect = projectedRect(
                size,
                in: viewportSize,
                transform: transform,
                contentMode: contentMode
            )
        else { return (0, 0) }

        return (
            Self.normalized(rect.minX, relativeTo: viewportSize.width / 2),
            Self.normalized(rect.maxX, relativeTo: viewportSize.width / 2)
        )
    }

    public func yFromCenter(
        _ size: borrowing some PlatySize,
        in viewportSize: CGSize,
        transform: CGAffineTransform = .identity,
        contentMode: ContentMode = .fill
    ) -> (Float, Float) {
        guard
            let rect = projectedRect(
                size,
                in: viewportSize,
                transform: transform,
                contentMode: contentMode
            )
        else { return (0, 0) }

        return (
            Self.normalized(rect.minY, relativeTo: viewportSize.height / 2),
            Self.normalized(rect.maxY, relativeTo: viewportSize.height / 2)
        )
    }

    public func normVector(
        _ size: borrowing some PlatySize,
        in viewportSize: CGSize,
        transform: CGAffineTransform = .identity,
        contentMode: ContentMode = .fill
    ) -> (Float, Float) {
        guard
            let rect = projectedRect(
                size,
                in: viewportSize,
                transform: transform,
                contentMode: contentMode
            )
        else { return (0, 0) }

        return (
            Self.normalized(rect.midX, relativeTo: viewportSize.width / 2),
            Self.normalized(rect.midY, relativeTo: viewportSize.height / 2)
        )
    }

    // This center remains in the detector's raw image coordinates.
    public func centerOfMass() -> CGPoint {
        CGPoint(
            x: CGFloat((xyxy.x1 + xyxy.x2) / 2),
            y: CGFloat((xyxy.y1 + xyxy.y2) / 2)
        )
    }

    private func projectedRect(
        _ size: borrowing some PlatySize,
        in viewportSize: CGSize,
        transform: CGAffineTransform,
        contentMode: ContentMode
    ) -> CGRect? {
        guard size.pixelWidth > 0, size.pixelHeight > 0,
            viewportSize.width > 0, viewportSize.height > 0
        else { return nil }

        return DetectionBoxProjection.rect(
            for: xyxy,
            imageSize: CGSize(width: size.pixelWidth, height: size.pixelHeight),
            viewportSize: viewportSize,
            transform: transform,
            contentMode: contentMode
        )
    }

    private static func normalized(_ point: CGFloat, relativeTo center: CGFloat)
        -> Float
    {
        Float((point - center) / center).clamped(to: -1...1)
    }
}

extension Float {
    fileprivate func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
