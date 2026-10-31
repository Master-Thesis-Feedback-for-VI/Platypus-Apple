//
//  ImageDetections+Extension.swift
//  Platypus
//
//  Created by Yann Bernard on 21.09.26.
//

import Foundation

extension ImageDetections {
    var summaries: [DetectionSummary] {
        let detectionTypes = self.asPlatyDetectionTypes()
        let grouped = Dictionary(
            grouping: detectionTypes,
            by: { detection in
                "\(detection.displayName)-\(detection.symbolName)"
            }
        )

        return
            grouped
            .map { key, matches in
                let first = matches[0]

                return DetectionSummary(
                    displayName: first.displayName,
                    symbolName: first.symbolName,
                    count: matches.count
                )
            }
            .sorted {
                $0.displayName.localizedStandardCompare($1.displayName)
                    == .orderedAscending
            }
    }
    
    func asPlatyDetectionTypes() -> [PlatyDetectionType] {
        let detectionTypes = self.detections.compactMap {
            let detectionType = $0.name
            return PlatyDetectionType(detectionType: detectionType)
        }
        return detectionTypes
    }
}

struct DetectionSummary: Identifiable, Hashable, DisplayableProto {
    let displayName: String
    let symbolName: String
    let count: Int

    var id: String {
        "\(displayName)-\(symbolName)"
    }

    var displayTitle: String {
        if count == 1 {
            return displayName
        }

        return "\(count) × \(displayName)"
    }
}
