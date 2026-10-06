//
//  Sounds.swift
//  Platypus
//
//  Created by Yann Bernard on 06.10.26.
//

import Foundation

struct SoundFile: Hashable {
    let fileName: String
    let ext: String

    init(_ fileName: String, ext: String = "wav") {
        self.fileName = fileName
        self.ext = ext
    }
}

protocol Earconable {
    var soundFile: SoundFile { get }
}

extension PlatyDetectionType: Earconable {
    var soundFile: SoundFile {
        switch self {
        case .car: SoundFile("car")
        case .person: SoundFile("person")
        case .bench: SoundFile("bench")
        case .bicycle: SoundFile("bicycle")
        }
    }
}
