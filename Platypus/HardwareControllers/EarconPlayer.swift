import AVFoundation
import Combine

// MARK: - Directions (16 steps of 22.5°, 0° = front, 90° = right)

enum Direction: Double, CaseIterable {
    case front = 0
    case frontFrontRight = 22.5
    case frontRight = 45
    case frontRightRight = 67.5
    case right = 90
    case backRightRight = 112.5
    case backRight = 135
    case backBackRight = 157.5
    case back = 180
    case backBackLeft = 202.5
    case backLeft = 225
    case backLeftLeft = 247.5
    case left = 270
    case frontLeftLeft = 292.5
    case frontLeft = 315
    case frontFrontLeft = 337.5

    var azimuth: Double { rawValue }
}

// MARK: - Earcons (rawValue = file name of a MONO file in the app bundle)

enum Earcon: String, CaseIterable {
    case ping
    case success
    case error
    case turnLeft
    case turnRight
}

// MARK: - Polar -> 3D point (listener at origin, facing -Z, +X = right, +Y = up)

extension AVAudio3DPoint {
    static func polar(
        azimuth: Double,
        elevation: Double = 0,
        distance: Float = 2
    ) -> AVAudio3DPoint {
        let az = Float(azimuth * .pi / 180)
        let el = Float(elevation * .pi / 180)
        return AVAudio3DPoint(
            x: distance * cos(el) * sin(az),
            y: distance * sin(el),
            z: -distance * cos(el) * cos(az)
        )
    }
}

// MARK: - Earcon player

/// Empty ObservableObject conformance: only needed so it works with
/// @StateObject / .environmentObject. Nothing is published.
final class EarconPlayer: ObservableObject {
    enum EarconError: Error {
        case fileNotFound(String)
        case bufferFailed(String)
    }

    private struct Voice {
        let node: AVAudioPlayerNode
        let buffer: AVAudioPCMBuffer
    }

    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private var voices: [Earcon: Voice] = [:]

    /// false if loading files or starting the engine failed (see console)
    private(set) var isReady = false

    /// - Parameters:
    ///   - ext: file extension of all earcon files (e.g. "wav")
    ///   - earcons: which earcons to load (default: all)
    init(ext: String = "wav", earcons: [Earcon] = Earcon.allCases) {
        do {
            try setUp(ext: ext, earcons: earcons)
            isReady = true
        } catch {
            print("EarconPlayer setup failed: \(error)")
        }
    }

    private func setUp(ext: String, earcons: [Earcon]) throws {
        engine.attach(environment)

        // Listener at origin, looking toward -Z
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.listenerAngularOrientation =
            AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)

        for earcon in earcons {
            guard
                let url = Bundle.main.url(
                    forResource: earcon.rawValue,
                    withExtension: ext
                )
            else {
                throw EarconError.fileNotFound(earcon.rawValue)
            }

            let file = try AVAudioFile(forReading: url)
            guard
                let buf = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: AVAudioFrameCount(file.length)
                )
            else {
                throw EarconError.bufferFailed(earcon.rawValue)
            }
            try file.read(into: buf)

            let node = AVAudioPlayerNode()
            engine.attach(node)
            try engine.connectNode(node, to: environment, format: buf.format)  // mono format

            // Spatialization settings
            node.renderingAlgorithm = .HRTFHQ  // best for headphones
            node.sourceMode = .spatializeIfMono
            node.reverbBlend = 0  // dry sound, clearer direction

            voices[earcon] = Voice(node: node, buffer: buf)
        }

        try engine.connectNode(environment, to: engine.mainMixerNode, format: nil)

        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)

        engine.prepare()
        try engine.start()
    }

    // MARK: Playing

    func play(
        _ earcon: Earcon,
        from direction: Direction,
        elevation: Double = 0,
        distance: Float = 2
    ) {
        play(
            earcon,
            azimuth: direction.azimuth,
            elevation: elevation,
            distance: distance
        )
    }

    /// Any angle: 0 = front, 90 = right, 180 = back, 270 = left
    func play(
        _ earcon: Earcon,
        azimuth: Double,
        elevation: Double = 0,
        distance: Float = 2
    ) {
        guard isReady, let voice = voices[earcon] else { return }
        voice.node.position = .polar(
            azimuth: azimuth,
            elevation: elevation,
            distance: distance
        )
        voice.node.scheduleBuffer(voice.buffer, at: nil, options: .interrupts)
        if !voice.node.isPlaying {
            do { try voice.node.playAudio() }
            catch { print("Earcon \(earcon) failed to play: \(error)") }
        }
    }

    /// Plays one earcon from all 16 directions one after another, for testing.
    func playSweep(_ earcon: Earcon, interval: TimeInterval = 1.0) {
        for (i, direction) in Direction.allCases.enumerated() {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + interval * Double(i)
            ) { [weak self] in
                print("Playing \(earcon) from \(direction)")
                self?.play(earcon, from: direction)
            }
        }
    }

    func stop() {
        voices.values.forEach { $0.node.stop() }
        engine.stop()
    }
}
