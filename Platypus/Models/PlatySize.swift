//
//  PlatySize.swift
//  Platypus
//
//  Created by Yann Bernard on 26.09.26.
//

import Foundation
import AVFoundation

public protocol PlatySize {
    var pixelHeight: Int { get }
    var pixelWidth: Int { get }
}

public extension PlatySize {
    var center: CGPoint {
        let heightCenter = Double(self.pixelHeight) / 2.0
        let widthCenter = Double(self.pixelWidth) / 2.0
        
        return CGPoint(x: widthCenter, y: heightCenter)
    }
}


extension CGSize: PlatySize {
    public var pixelWidth: Int {
        Int(self.width)
    }

    public var pixelHeight: Int {
        Int(self.height)
    }
}
