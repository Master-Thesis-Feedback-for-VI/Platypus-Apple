//
//  PlatyDetections.swift
//  Platypus
//
//  Created by Yann Bernard on 11.10.26.
//

import Foundation
import SwiftUI

nonisolated struct PlatyDetections: Codable {
    let inner: [PlatyDetection]
}

extension PlatyDetections {
    init<Frame: PlatySize, D: Sequence>(
        detections: D,
        frameSize: Frame,
        viewportSize: CGSize,
        imageTransform: CGAffineTransform,
        contentMode: ContentMode
    ) where D.Element == Detection {
        let converted: [PlatyDetection] = detections.compactMap { detection in
            PlatyDetection(
                detection: detection,
                frameSize: frameSize,
                viewportSize: viewportSize,
                imageTransform: imageTransform,
                contentMode: contentMode
            )
        }

        self = converted.collect()
    }
}

extension PlatyDetections {
    func filteredForFeedback(
        settings: [PlatyDetectionType: ProfileDetectionSettings],
        channel: FeedbackChannel
    ) -> PlatyDetections {
        inner.filter { detection in
            guard let setting = settings[detection.detectionType] else { return false }
            let centralOnly = switch channel {
            case .sound: setting.soundOnlyTriggerIfCentral
            case .haptic: setting.hapticOnlyTriggerIfCentral
            }
            return !centralOnly || detection.isCentral
        }.collect()
    }

    var closestDetection: PlatyDetection? {
        self.inner.min { det1, det2 in
            det1.distance < det2.distance
        }
    }

    func closestWihtin(_ distanceInMetersDiff: Float) -> PlatyDetections {
        guard let closest = self.closestDetection else {
            return PlatyDetections(inner: [])
        }

        return self
            .inner
            .filter {
                let diffDist = abs(closest.distance - $0.distance)
                return diffDist < distanceInMetersDiff
            }
            .collect()
    }
}

extension Array: Collectable where Element == PlatyDetection {
    typealias Output = PlatyDetections

    func collect() -> PlatyDetections {
        PlatyDetections(inner: self)
    }
}
