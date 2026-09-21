//
//  ImageDetections+Sequence.swift
//  Platypus
//
//  Created by Yann Bernard on 21.09.26.
//

extension ImageDetections: RandomAccessCollection {
    public typealias Element = Detection
    public typealias Index = Int

    public var startIndex: Int { detections.startIndex }
    public var endIndex: Int { detections.endIndex }

    public func index(after i: Int) -> Int {
        detections.index(after: i)
    }

    public subscript(index: Int) -> Detection {
        detections[index]
    }
}
