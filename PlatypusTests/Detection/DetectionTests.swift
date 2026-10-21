//
//  DetectionTests.swift
//  Platypus
//
//  Created by Yann Bernard on 28.09.26.
//

import Testing
@testable import Platypus
import SwiftUI

@MainActor
struct DetectionTests {
    @Test func normTests() throws {
        let screen = ScreenMock()
        
        let bbox = BoundingBox(x1: 100, x2: 200, y1: 100, y2: 200)
        let detection = try #require(PlatyDetection(
            detection: Detection(name: .person, xyxy: bbox, distance: 0, confidence: 0.8),
            frameSize: screen,
            viewportSize: CGSize(width: 1000, height: 1000),
            imageTransform: .identity,
            contentMode: .fill
        ))
        
        let expectedCenterOfMass = CGPoint(x: 150, y: 150)
        let expectedXNormVector: (Double, Double) = (-0.8, -0.6)
        let expectedYNormVector: (Double, Double) = (-0.8, -0.6)
        
        let centerOfMass = CGPoint(x: detection.rect.midX, y: detection.rect.midY)
        let xCenter = detection.xFromCenter()
        let yCenter = detection.yFromCenter()
        let vector = detection.normVector
        #expect(expectedCenterOfMass == centerOfMass)
        #expect(expectedXNormVector == xCenter)
        #expect(expectedYNormVector == yCenter)
        #expect(vector == CGPoint(x: -0.7, y: -0.7))
    }

    @Test func rotatedDetectionUsesDisplayedAxes() throws {
        let image = ImageSize(pixelHeight: 300, pixelWidth: 400)
        let box = BoundingBox(x1: 100, x2: 200, y1: 50, y2: 150)
        let rotation = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 300, ty: 0)

        let detection = try #require(PlatyDetection(
            detection: Detection(name: .person, xyxy: box, distance: 0, confidence: 0.8),
            frameSize: image,
            viewportSize: CGSize(width: 300, height: 400),
            imageTransform: rotation,
            contentMode: .fill
        ))
        let x = detection.xFromCenter()
        let y = detection.yFromCenter()
        let vector = detection.normVector

        #expect(x == (0, 2.0 / 3.0))
        #expect(y == (-0.5, 0))
        #expect(vector == CGPoint(x: 1.0 / 3.0, y: -0.25))
    }

    @Test func croppedDetectionUsesViewportCenter() throws {
        let image = ImageSize(pixelHeight: 300, pixelWidth: 400)
        let box = BoundingBox(x1: 100, x2: 200, y1: 50, y2: 150)
        let detection = try #require(PlatyDetection(
            detection: Detection(name: .person, xyxy: box, distance: 0, confidence: 0.8),
            frameSize: image,
            viewportSize: CGSize(width: 200, height: 300),
            imageTransform: .identity,
            contentMode: .fill
        ))

        let x = detection.xFromCenter()
        #expect(x == (-1, 0))
    }
}

private struct ScreenMock: PlatySize {
    let pixelHeight: Int = 1000
    let pixelWidth: Int = 1000
}

private struct ImageSize: PlatySize {
    let pixelHeight: Int
    let pixelWidth: Int
}
