//
//  Sounds.swift
//  Platypus
//
//  Created by Yann Bernard on 06.10.26.
//

import AVFoundation
import Foundation

nonisolated struct SoundFile: Hashable {
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

// TODO: Front front right or front front right it should depend on the screen where something is positioned
@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, _ volume: Float = 1.0) {
        guard currentUtterance == nil else { return }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.volume = min(1.0, max(0.0, volume))
        currentUtterance = utterance
        synthesizer.speak(utterance)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.finish(id) }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.finish(id) }
    }

    private func finish(_ id: ObjectIdentifier) {
        guard let currentUtterance, ObjectIdentifier(currentUtterance) == id else {
            return
        }
        self.currentUtterance = nil
    }
}
