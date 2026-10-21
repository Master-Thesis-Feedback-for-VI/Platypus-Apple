import CoreGraphics
@testable import Platypus
import SwiftUI
import Testing

@MainActor
struct DetectionBoxProjectionTests {
    private let box = BoundingBox(x1: 100, x2: 200, y1: 50, y2: 150)

    @Test func aspectFillAccountsForCrop() throws {
        let rect = try projectedRect(
            for: box,
            imageSize: CGSize(width: 400, height: 300),
            viewportSize: CGSize(width: 200, height: 300),
            transform: .identity,
            contentMode: .fill
        )

        #expect(rect == CGRect(x: 0, y: 50, width: 100, height: 100))
    }

    @Test func aspectFitAccountsForLetterboxing() throws {
        let rect = try projectedRect(
            for: box,
            imageSize: CGSize(width: 400, height: 300),
            viewportSize: CGSize(width: 200, height: 300),
            transform: .identity,
            contentMode: .fit
        )

        #expect(rect == CGRect(x: 50, y: 100, width: 50, height: 50))
    }

    @Test func rotationProjectsRawPixelCoordinates() throws {
        let rect = try projectedRect(
            for: box,
            imageSize: CGSize(width: 400, height: 300),
            viewportSize: CGSize(width: 300, height: 400),
            transform: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 300, ty: 0),
            contentMode: .fit
        )

        #expect(rect == CGRect(x: 150, y: 100, width: 100, height: 100))
    }

    private func projectedRect(
        for box: BoundingBox,
        imageSize: CGSize,
        viewportSize: CGSize,
        transform: CGAffineTransform,
        contentMode: ContentMode
    ) throws -> CGRect {
        let detection = try #require(PlatyDetection(
            detection: Detection(name: .person, xyxy: box, distance: 0, confidence: 0.8),
            frameSize: ProjectionImageSize(
                pixelHeight: Int(imageSize.height),
                pixelWidth: Int(imageSize.width)
            ),
            viewportSize: viewportSize,
            imageTransform: transform,
            contentMode: contentMode
        ))
        return detection.rect
    }
}

private struct ProjectionImageSize: PlatySize {
    let pixelHeight: Int
    let pixelWidth: Int
}
