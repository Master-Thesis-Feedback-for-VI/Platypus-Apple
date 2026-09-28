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
        let expectedXNormVector: (Float, Float) = (0.8, 0.6)
        let expectedYNormVector: (Float, Float) = (0.8, 0.6)
        
        let centerOfMass = await detection.centerOfMass()
        let xCenter = await detection.xFromCenter(screen)
        let yCenter = await detection.yFromCenter(screen)
        #expect(expectedCenterOfMass == centerOfMass)
        #expect(expectedXNormVector == xCenter)
        #expect(expectedYNormVector == yCenter)
    }
}

private struct ScreenMock: PlatySize {
    let pixelHeight: Int = 1000
    let pixelWidth: Int = 1000
}
