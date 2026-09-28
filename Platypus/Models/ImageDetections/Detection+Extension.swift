import AVFoundation
import Foundation

//
//  Detection+Extension.swift
//  Platypus
//
//  Created by Yann Bernard on 26.09.26.
//

extension Detection {
    public func xFromCenter(_ size: borrowing some PlatySize) -> (Float, Float)
    {
        let center = size.center
        let x1Norm = Self.normalized(center.x, CGFloat(self.xyxy.x1)).clamped(
            to: -1.0...1.0
        )
        let x2Norm = Self.normalized(center.x, CGFloat(self.xyxy.x2)).clamped(
            to: -1.0...1.0
        )

        return (x1Norm, x2Norm)
    }

    public func yFromCenter(_ size: borrowing some PlatySize) -> (Float, Float)
    {
        let center = size.center
        let y1Norm = Self.normalized(center.y, CGFloat(self.xyxy.y1)).clamped(
            to: -1.0...1.0
        )
        let y2Norm = Self.normalized(center.y, CGFloat(self.xyxy.y2)).clamped(
            to: -1.0...1.0
        )

        return (y1Norm, y2Norm)
    }

    public func normVector(_ size: borrowing some PlatySize) -> (Float, Float) {
        let frameCenter = size.center
        let mass = centerOfMass()

        let dx = mass.x - frameCenter.x
        let dy = mass.y - frameCenter.y

        let nx = Float(dx / frameCenter.x).clamped(to: -1.0...1.0)
        let ny = Float(dy / frameCenter.y).clamped(to: -1.0...1.0)

        return (nx, ny)
    }

    public func centerOfMass() -> CGPoint {
        let centerX = CGFloat((xyxy.x1 + xyxy.x2) / 2.0)
        let centerY = CGFloat((xyxy.y1 + xyxy.y2) / 2.0)
        return CGPoint(x: centerX, y: centerY)
    }

    static private func normalized(_ long: CGFloat, _ detectionPoint: CGFloat)
        -> Float
    {
        let toCenterDiff = long - detectionPoint
        return Float(toCenterDiff / long)
    }
}

extension Float {
    fileprivate func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
