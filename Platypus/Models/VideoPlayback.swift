//
//  VideoPlayback.swift
//  Platypus
//
//  Created by Yann Bernard on 24.09.26.
//

import Foundation

struct VideoPlayback: Identifiable {
    let id = UUID()
    let evaluations: [ImageFlowEvaluationForRecording]
    let videoPath: URL

    //    private var lastIndex: Int = 0
}

extension VideoPlayback {
    func findEvaluation(_ timeDiff: Double) -> ImageFlowEvaluationForRecording {
        var bestDiff = Double.greatestFiniteMagnitude
        var bestIdx = 0

        //        for (idx, evaluation) in evaluations.enumerated() {
        for (idx, evaluation) in evaluations.enumerated() {
            let diff = abs(timeDiff - evaluation.timeDiff())
            if diff < bestDiff {
                bestDiff = diff
                bestIdx = idx
            } else if diff > bestDiff {
                break
            }
        }

        return evaluations[bestIdx]
    }
}
