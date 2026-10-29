import CoreGraphics
import ImageIO
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

    @Test(arguments: 1...8)
    func photoDimensionsMatchOrientedInference(orientation: Int) throws {
        let image = try photo(orientation: orientation)
        let expectedSize = (5...8).contains(orientation)
            ? CGSize(width: 300, height: 400)
            : CGSize(width: 400, height: 300)

        #expect(image.pixelSize == expectedSize)
    }

    @Test(arguments: [
        CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1920, ty: 0),
        CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 1080)
    ])
    func uprightVideoBoxesAreNotRotatedTwice(trackTransform: CGAffineTransform) throws {
        let naturalSize = CGSize(width: 1920, height: 1080)
        let uprightSize = CGRect(origin: .zero, size: naturalSize)
            .applying(trackTransform).size
        let rect = try projectedRect(
            for: BoundingBox(x1: 720, x2: 990, y1: 480, y2: 1440),
            imageSize: uprightSize,
            viewportSize: CGSize(width: 360, height: 640),
            transform: .identity,
            contentMode: .fit
        )

        #expect(uprightSize == CGSize(width: 1080, height: 1920))
        #expect(rect == CGRect(x: 240, y: 160, width: 90, height: 320))
    }

    @Test func portraitPhotoBoxesAreNotRotatedTwice() throws {
        let image = try photo(orientation: 6)
        let size = try #require(image.pixelSize)
        let rect = try projectedRect(
            for: box,
            imageSize: size,
            viewportSize: CGSize(width: 300, height: 600),
            transform: .identity,
            contentMode: .fill
        )

        #expect(rect == CGRect(x: 75, y: 75, width: 150, height: 150))
    }

    private func photo(orientation: Int) throws -> PlatyImage {
        let context = try #require(CGContext(
            data: nil,
            width: 400,
            height: 300,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        let pixels = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            data, "public.jpeg" as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, pixels, [
            kCGImagePropertyOrientation: orientation
        ] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return PlatyImage(img: data as Data)
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
