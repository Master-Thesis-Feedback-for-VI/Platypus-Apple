import AVFoundation
import Combine

// MARK: - Directions (16 steps of 22.5, 0 = front, 90 = right)

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
}

extension Direction {
    var azimuth: Double { rawValue }

    static func closest(to angle: Double) -> Direction {
        let a = angle.truncatingRemainder(dividingBy: 360)
        let normalized = a < 0 ? a + 360 : a

        return allCases.min {
            circularDistance($0.azimuth, normalized)
                < circularDistance($1.azimuth, normalized)
        } ?? .front
    }

    private static func circularDistance(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(diff, 360 - diff)
    }
}

extension Direction: CustomStringConvertible {
    var description: String {
        switch self {
        case .front: "front"
        case .frontFrontRight: "front front right"
        case .frontRight: "front right"
        case .frontRightRight: "front right right"
        case .right: "right"
        case .backRightRight: "back right right"
        case .backRight: "back right"
        case .backBackRight: "back back right"
        case .back: "back"
        case .backBackLeft: "back back left"
        case .backLeft: "back left"
        case .backLeftLeft: "back left left"
        case .left: "left"
        case .frontLeftLeft: "front left left"
        case .frontLeft: "front left"
        case .frontFrontLeft: "front front left"
        }
    }
}

// MARK: - Polar -> 3D point (listener at origin, facing -Z, +X = right, +Y = up)

extension AVAudio3DPoint {
    nonisolated static func polar(
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

// MARK: - Audio backend

@MainActor
private final class EarconBackend {
    private struct Voice {
        let node: AVAudioPlayerNode
        let buffer: AVAudioPCMBuffer
    }

    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private var voices: [SoundFile: Voice] = [:]
    private var lastPlayed: [SoundFile: ContinuousClock.Instant] = [:]
    private var playing: [SoundFile: UUID] = [:]

    func setUp(files: [SoundFile]) async throws {
        let files = files.filter { !$0.skip }
        let activated = try await Task.detached {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            return try await session.activate()
        }.value
        try Task.checkCancellation()
        guard activated else {
            throw EarconPlayer.EarconError.activationFailed
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
            else { throw EarconPlayer.EarconError.fileNotFound(file.fileName) }

            let audioFile = try AVAudioFile(forReading: url)
            guard audioFile.length > 0 else {
                throw EarconPlayer.EarconError.bufferFailed(file.fileName)
            }
            guard
                let buf = AVAudioPCMBuffer(
                    pcmFormat: audioFile.processingFormat,
                    frameCapacity: AVAudioFrameCount(audioFile.length)
                )
            else { throw EarconPlayer.EarconError.bufferFailed(file.fileName) }
            try audioFile.read(into: buf)
            guard buf.frameLength > 0 else {
                throw EarconPlayer.EarconError.bufferFailed(file.fileName)
            }

            let node = AVAudioPlayerNode()
            engine.attach(node)
            try engine.connectNode(node, to: environment, format: buf.format)
            node.renderingAlgorithm = .HRTF
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

    func play(
        file: SoundFile,
        volume: Float,
        azimuth: Double,
        elevation: Double,
        distance: Float
    ) {
        guard let voice = voices[file], !file.skip else {
            print("Earcon not loaded: \(file.fileName)")
            return
        }

        guard playing[file] == nil else { return }

        if let previous = lastPlayed[file],
            ContinuousClock.now - previous < .milliseconds(400)
        {
            return
        }

        voice.node.volume = volume
        voice.node.position = .polar(
            azimuth: azimuth,
            elevation: elevation,
            distance: distance
        )
        let playbackID = UUID()
        playing[file] = playbackID
        voice.node.scheduleBuffer(
            voice.buffer,
            at: nil,
            options: [],
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.playing[file] == playbackID else { return }
                self?.playing.removeValue(forKey: file)
            }
        }
        do {
            if !voice.node.isPlaying {
                try voice.node.playAudio()
            }
            lastPlayed[file] = ContinuousClock.now
        } catch {
            playing.removeValue(forKey: file)
            voice.node.stop()
            print("Earcon \(file.fileName) failed to play: \(error)")
        }
    }

    func stop() {
        voices.values.forEach { $0.node.stop() }
        engine.stop()
        voices.removeAll()
        lastPlayed.removeAll()
        playing.removeAll()
    }
}

// MARK: - Earcon player (main-actor facade)

/// Empty ObservableObject conformance: only needed for @StateObject / .environmentObject.
@MainActor
final class EarconPlayer: ObservableObject {
    enum EarconError: Error {
        case fileNotFound(String)
        case bufferFailed(String)
        case activationFailed
    }

    private lazy var backend = EarconBackend()
    private let files: [SoundFile]
    private var setupTask: Task<Void, Never>?

    private(set) var isReady = false

    init(earcons: [any Earconable]) {
        files =
            earcons
            .map(\.soundFile)
            .filter { !$0.skip }
    }

    convenience init<E: Earconable & CaseIterable>(_ type: E.Type) {
        self.init(earcons: Array(E.allCases))
    }

    func waitUntilReady() async {
        if setupTask == nil {
            let backend = backend
            let files = files
            setupTask = Task { [weak self] in
                do {
                    try await backend.setUp(files: files)
                    self?.isReady = true
                } catch {
                    print("EarconPlayer setup failed: \(error)")
                }
            }
        }
        await setupTask?.value
    }

    // MARK: Playing

    func play(
        _ earcon: some Earconable,
        volume: Float,
        from direction: Direction,
        elevation: Double = 0,
        distance: Float = 2
    ) async {
        await play(
            earcon,
            volume: volume,
            azimuth: direction.azimuth,
            elevation: elevation,
            distance: distance
        )
    }

    func play(
        _ earcon: some Earconable,
        volume: Float,
        azimuth: Double,
        elevation: Double = 0,
        distance: Float = 2
    ) async {
        await waitUntilReady()
        guard !Task.isCancelled, isReady, !earcon.soundFile.skip else { return }
        backend.play(
            file: earcon.soundFile,
            volume: volume,
            azimuth: azimuth,
            elevation: elevation,
            distance: distance
        )
    }

    func playSweep(
        _ earcon: some Earconable,
        interval: Duration = .seconds(1.5),
        volume: Float = 0.5
    ) async {
        for direction in Direction.allCases {
            if Task.isCancelled { return }
            await play(earcon, volume: volume, from: direction)
            do { try await Task.sleep(for: interval) } catch { return }
        }
    }

    func stop() {
        isReady = false
        setupTask?.cancel()
        backend.stop()
    }
}
