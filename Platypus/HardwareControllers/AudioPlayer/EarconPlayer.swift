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
@MainActor
final class EarconPlayer: ObservableObject {
    enum EarconError: Error {
        case fileNotFound(String)
        case bufferFailed(String)
        case activationFailed
    }

    private struct Voice {
        let node: AVAudioPlayerNode
        let buffer: AVAudioPCMBuffer
    }

    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private var voices: [SoundFile: Voice] = [:]
    private var setupTask: Task<Void, Never>?

    private(set) var isReady = false

    init(earcons: [any Earconable]) {
        let files = earcons.map(\.soundFile)
        setupTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.setUp(files: files)
                self.isReady = true
            } catch {
                print("EarconPlayer setup failed: \(error)")
            }
        }
    }

    convenience init<E: Earconable & CaseIterable>(_ type: E.Type) {
        self.init(earcons: Array(E.allCases))
    }

    /// Await this if you need to play right after creation.
    func waitUntilReady() async { await setupTask?.value }

    private func setUp(files: [SoundFile]) async throws {
        // Configure first, then activate asynchronously (iOS 27)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback)
        guard try await session.activate() else {
            throw EarconError.activationFailed
        }

        engine.attach(environment)
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.listenerAngularOrientation =
            AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)

        for file in Set(files) {
            guard
                let url = Bundle.main.url(
                    forResource: file.fileName,
                    withExtension: file.ext
                )
            else { throw EarconError.fileNotFound(file.fileName) }

            let audioFile = try AVAudioFile(forReading: url)
            guard
                let buf = AVAudioPCMBuffer(
                    pcmFormat: audioFile.processingFormat,
                    frameCapacity: AVAudioFrameCount(audioFile.length)
                )
            else { throw EarconError.bufferFailed(file.fileName) }
            try audioFile.read(into: buf)

            let node = AVAudioPlayerNode()
            engine.attach(node)
            try engine.connectNode(node, to: environment, format: buf.format)
            node.renderingAlgorithm = .HRTFHQ
            node.sourceMode = .spatializeIfMono
            node.reverbBlend = 0
            voices[file] = Voice(node: node, buffer: buf)
        }

        try engine.connectNode(
            environment,
            to: engine.mainMixerNode,
            format: nil
        )
        engine.prepare()
        try engine.start()
    }

    // MARK: Playing

    func play(
        _ earcon: some Earconable,
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

    func play(
        _ earcon: some Earconable,
        azimuth: Double,
        elevation: Double = 0,
        distance: Float = 2
    ) {
        guard isReady, let voice = voices[earcon.soundFile] else {
            print("Earcon not loaded: \(earcon.soundFile.fileName)")
            return
        }
        voice.node.position = .polar(
            azimuth: azimuth,
            elevation: elevation,
            distance: distance
        )
        voice.node.scheduleBuffer(voice.buffer, at: nil, options: .interrupts)
        if !voice.node.isPlaying {
            do { try voice.node.playAudio() } catch {
                print("Earcon \(earcon) failed to play: \(error)")
            }
        }
    }

    func playSweep(_ earcon: some Earconable, interval: Duration = .seconds(1.5))
        async
    {
        for direction in Direction.allCases {
            if Task.isCancelled { return }
            play(earcon, from: direction)
            do { try await Task.sleep(for: interval) } catch { return }
        }
    }

    func stop() {
        voices.values.forEach { $0.node.stop() }
        engine.stop()
        isReady = false
    }
}
