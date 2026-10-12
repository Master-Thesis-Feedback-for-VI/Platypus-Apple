//
//  PlatyGroupedDetections.swift
//  Platypus
//
//  Created by Yann Bernard on 11.10.26.
//

import SwiftUI

struct PlatyGroupedDetections {
    let inner: PlatyDetections
    let containedType: PlatyDetectionType
}

extension PlatyGroupedDetections {
    init(
        from detections: PlatyDetections,
        on detectionType: PlatyDetectionType,
    ) {
        let detections: PlatyDetections = detections
            .inner
            .filter {
                $0.detectionType == detectionType
            }
            .collect()

        self.inner = detections
        self.containedType = detectionType
    }
}

extension PlatyGroupedDetections {
    var closestDetection: PlatyDetection? {
        self.inner.closestDetection
    }

    var averageDistance: Double {
        let detections = self.detectionsUnwrap
        return detections.reduce(0.0) { $0 + Double($1.distance) }
            / Double(detections.count)
    }

    func closestWihtin(_ distanceInMetersDiff: Float) -> PlatyDetections {
        self.inner.closestWihtin(distanceInMetersDiff)
    }

    func groupedSelection(_ distanceInMetersDiff: Float = 0.5)
        -> SelectedGrouped?
    {
        guard let closest = self.closestDetection,
            !self.detectionsUnwrap.isEmpty
        else { return nil }
        
        let filteredGroup = self.closestWihtin(distanceInMetersDiff)
        let detectionsIntersecting = filteredGroup.inner.filter { current in
            current.rect.intersects(closest.rect)
        }.collect()
        let boundingRect = detectionsIntersecting.inner.map(\.rect).reduce(
            nil as CGRect?
        ) { result, rect in
            result?.union(rect) ?? rect
        }!
        let groupedIntersection = PlatyGroupedDetections(
            from: detectionsIntersecting,
            on: self.containedType
        )

        return SelectedGrouped(
            detections: detectionsIntersecting,
            rect: boundingRect,
            distance: groupedIntersection.averageDistance,
            detectionType: self.containedType,
            viewportSize: detectionsIntersecting.inner.first!.viewportSize
        )
    }

    private var detectionsUnwrap: [PlatyDetection] {
        self.inner.inner
    }
}

struct SelectedGrouped {
    let detections: PlatyDetections
    let rect: CGRect
    let distance: Double
    let detectionType: PlatyDetectionType
    let viewportSize: CGSize
}

extension SelectedGrouped {
    var xFromCenter: (Double, Double) {
        let detections = self.detections.inner
        let (leftBound, rightBound) = detections.reduce(
            (0.0, 0.0)
        ) { acc, detection in
            let xFromCenter = detection.xFromCenter()
            return (
                acc.0 + xFromCenter.0,
                acc.1 + xFromCenter.1
            )
        }

        let amount = Double(detections.count)
        return (
            leftBound / amount,
            rightBound / amount
        )
    }
}

extension SelectedGrouped: Normalizable {
    var normVector: CGPoint {
        let point = CGPoint(
            x: normalized(rect.midX, relativeTo: viewportSize.width / 2),
            y: normalized(rect.midY, relativeTo: viewportSize.height / 2)
        )
        return point
    }
}
