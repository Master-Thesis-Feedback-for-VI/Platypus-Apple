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
}

// TODO: extend this so frames can be found by timestamp
