//
//  DetectionTests.swift
//  Platypus
//
//  Created by Yann Bernard on 28.09.26.
//

import Testing
import Platypus
import AVFoundation

struct DetectionTests {
    @Test func normTests() async {
        let screen = await ScreenMock()
        
        let bbox = await BoundingBox(x1: 100, x2: 200, y1: 100, y2: 200)
        let detection = await Detection(confidence: 0.8, name: .person, xyxy: bbox)
        
        let expectedCenterOfMass = CGPoint(x: 150, y: 150)
        let expectedXNormVector: (Float, Float) = (-0.8, -0.6)
        let expectedYNormVector: (Float, Float) = (-0.8, -0.6)
        
        let centerOfMass = await detection.centerOfMass()
        let xCenter = await detection.xFromCenter(screen, in: CGSize(width: 1000, height: 1000))
        let yCenter = await detection.yFromCenter(screen, in: CGSize(width: 1000, height: 1000))
        let vector = await detection.normVector(screen, in: CGSize(width: 1000, height: 1000))
        #expect(expectedCenterOfMass == centerOfMass)
        #expect(expectedXNormVector == xCenter)
        #expect(expectedYNormVector == yCenter)
        #expect(vector == (-0.7, -0.7))
    }

    @Test func rotatedDetectionUsesDisplayedAxes() async {
        let image = ImageSize(pixelHeight: 300, pixelWidth: 400)
        let box = await BoundingBox(x1: 100, x2: 200, y1: 50, y2: 150)
        let detection = await Detection(confidence: 0.8, name: .person, xyxy: box)
        let rotation = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 300, ty: 0)

        let x = await detection.xFromCenter(image, in: CGSize(width: 300, height: 400), transform: rotation)
        let y = await detection.yFromCenter(image, in: CGSize(width: 300, height: 400), transform: rotation)
        let vector = await detection.normVector(image, in: CGSize(width: 300, height: 400), transform: rotation)

        #expect(x == (0, 2.0 / 3.0))
        #expect(y == (-0.5, 0))
        #expect(vector == (1.0 / 3.0, -0.25))
    }

    @Test func croppedDetectionUsesViewportCenter() async {
        let image = ImageSize(pixelHeight: 300, pixelWidth: 400)
        let box = await BoundingBox(x1: 100, x2: 200, y1: 50, y2: 150)
        let detection = await Detection(confidence: 0.8, name: .person, xyxy: box)

        let x = await detection.xFromCenter(image, in: CGSize(width: 200, height: 300))
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
