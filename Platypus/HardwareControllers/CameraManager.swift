//
//  CameraManager.swift
//  Platypus
//
//  Created by Yann Bernard on 11.08.26.
//
//  Rewritten with structured concurrency for Swift 6 strict-checking mode.
//

import AVFoundation
import Combine
import Foundation

enum CameraError: Error {
    case deviceNotFound
    case alreadyRecording
    case notAuthorized
    case bundleNotCreated
}

/// Owns the `AVCaptureSession` and every AVFoundation call.
/// Isolating this to its own actor means configuration, start/stop,
/// and recording can never race with each other or with the main actor —
/// the compiler enforces it, so the old `sessionQueue` is no longer needed.
actor CameraSessionActor {
    static let SLEEP_DURATION: TimeInterval = 0.5

    // AVCaptureSession is documented by Apple as internally thread-safe,
    // which is exactly the situation `nonisolated(unsafe)` exists for:
    // we need synchronous, cross-actor access for an AVCaptureVideoPreviewLayer,
    // and we're deliberately vouching for its safety instead of hiding a race.
    nonisolated(unsafe) let session = AVCaptureSession()

    private let videoOutput = AVCaptureMovieFileOutput()
    private let recordingDelegate = RecordingDelegateProxy()

    private var fileBundler = FileBundler(createDir: false)

    struct RecordingResult {
        let videoURL: URL
        let bundledURL: URL
    }

    // MARK: - Camera Setup
    func configure() throws {
        session.beginConfiguration()
        session.sessionPreset = .high
        defer { session.commitConfiguration() }

        guard
            let videoDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            )
        else {
            throw CameraError.deviceNotFound
        }

        let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        if session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
        }

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
    }

    // MARK: - Session Control
    func startSession() {
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func stopSession() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    // MARK: - Video Capture
    /// Suspends until AVFoundation finishes writing the file, then
    /// resumes with the output URL or throws whatever error AVFoundation reported.
    func startRecording() async throws -> RecordingResult {
        guard !videoOutput.isRecording else {
            throw CameraError.alreadyRecording
        }

        enum MessageSnapshot {
            case cancel
            case sleepAwake
            case snapNowAndLeave
        }

        fileBundler = FileBundler()
        let fileBundlerCpy = fileBundler

        let (snapshotStream, snapshotContinuation) = AsyncStream<
            MessageSnapshot
        >.makeStream()
        let work = Task<URL?, Error> {
            let locationModel = await LocationRecorder()
            var gpsTimeStamps = await GPSTimestamps()
            let sleepTask = Task {
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(
                            nanoseconds: UInt64(
                                Self.SLEEP_DURATION * 1_000_000_000
                            )
                        )
                    } catch {
                        break
                    }

                    snapshotContinuation.yield(.sleepAwake)
                }
            }

            defer {
                sleepTask.cancel()
                snapshotContinuation.finish()
            }

            for await msg in snapshotStream {
                switch msg {
                case .cancel:
                    return nil

                case .sleepAwake:
                    guard let location = await locationModel.location else {
                        continue
                    }
                    let stamp = await GPSTimestampModel(location: location)

                    gpsTimeStamps.stamps.append(stamp)
                    if gpsTimeStamps.stamps.count > 10 {
                        try? await gpsTimeStamps.flush(
                            to: fileBundlerCpy.gpsDataFile
                        )
                    }

                case .snapNowAndLeave:
                    if let location = await locationModel.location {
                        await gpsTimeStamps.stamps.append(
                            GPSTimestampModel(location: location)
                        )
                    }
                    try? await gpsTimeStamps.flush(
                        to: fileBundlerCpy.gpsDataFile
                    )
                    return try fileBundlerCpy.saveBundled()
                }
            }

            return nil
        }

        let outputURL: URL
        do {
            outputURL = try await withCheckedThrowingContinuation {
                continuation in
                recordingDelegate.continuation = continuation
                recordingDelegate.onComplete = {
                    [snapshotContinuation] didSucceed in
                    snapshotContinuation.yield(
                        didSucceed ? .snapNowAndLeave : .cancel
                    )
                }
                videoOutput.startRecording(
                    to: fileBundler.videoFile,
                    recordingDelegate: recordingDelegate
                )
            }
        } catch {
            snapshotContinuation.yield(.cancel)
            snapshotContinuation.finish()
            work.cancel()
            _ = try? await work.value
            throw error
        }

        guard let bundledURL = try await work.value else {
            throw CameraError.bundleNotCreated
        }

        return RecordingResult(videoURL: outputURL, bundledURL: bundledURL)
    }

    func stopRecording() {
        guard videoOutput.isRecording else { return }
        videoOutput.stopRecording()
    }

    // MARK: - Preview
    func attachPreview(_ layer: AVCaptureVideoPreviewLayer) {
        session.beginConfiguration()
        layer.session = session
        session.commitConfiguration()
    }

    func detachPreview(_ layer: AVCaptureVideoPreviewLayer) {
        session.beginConfiguration()
        layer.session = nil
        session.commitConfiguration()
    }
}

/// `AVCaptureFileOutputRecordingDelegate` requires `NSObjectProtocol`
/// conformance, and its callback fires on an AVFoundation-owned thread —
/// not necessarily the actor's executor. Rather than forcing the actor
/// itself to conform, this tiny nonisolated shim just resolves a
/// continuation, which is the pattern recommended for bridging
/// delegate-based AVFoundation APIs into async/await.
nonisolated private final class RecordingDelegateProxy: NSObject,
    AVCaptureFileOutputRecordingDelegate
{
    var continuation: CheckedContinuation<URL, Error>?
    var onComplete: ((Bool) -> Void)?

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        let didSucceed = (error == nil)
        onComplete?(didSucceed)

        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume(returning: outputFileURL)
        }
        continuation = nil
        onComplete = nil
    }
}

@MainActor
final class CameraManager: ObservableObject {
    private let cameraActor = CameraSessionActor()
    private var activeRecordingTask:
        Task<CameraSessionActor.RecordingResult, Error>?

    /// Exposed synchronously for SwiftUI preview layers.
    //    nonisolated var session: AVCaptureSession { cameraActor.session }

    @Published var isCamAuthorized = false
    @Published var capturedVideo: Data?
    @Published var capturedVideoURL: URL?
    @Published var bundledRecordingURL: URL?
    @Published var recordingError: Error?
    @Published var isRecording = false

    init() {
        Task { await checkPermissions() }
    }

    // MARK: - Permissions
    private func checkPermissions() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCamAuthorized = true
            await setupCamera()
        case .notDetermined:
            // AVCaptureDevice.requestAccess has a native async overload,
            // so no completion handler / DispatchQueue.main.async hop is needed.
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            isCamAuthorized = granted
            if granted { await setupCamera() }
        default:
            isCamAuthorized = false
        }
    }

    private func setupCamera() async {
        do {
            try await cameraActor.configure()
        } catch {
            recordingError = error
        }
    }

    // MARK: - Session Control
    func startSession() async {
        await cameraActor.startSession()
    }

    func stopSession() async {
        await cameraActor.stopSession()
    }

    // MARK: - Video Capture
    func startRecording() async {
        guard !isRecording else { return }

        recordingError = nil
        bundledRecordingURL = nil
        isRecording = true

        let recordingTask = Task { try await cameraActor.startRecording() }
        activeRecordingTask = recordingTask
        defer {
            activeRecordingTask = nil
            isRecording = false
        }

        do {
            let result = try await recordingTask.value
            capturedVideoURL = result.videoURL
            bundledRecordingURL = result.bundledURL
            capturedVideo = try Data(contentsOf: result.videoURL)
        } catch {
            recordingError = error
        }
    }

    func stopRecording() async {
        let recordingTask = activeRecordingTask
        await cameraActor.stopRecording()
        _ = try? await recordingTask?.value
    }

    // MARK: - Preview
    // CameraManager
    func attachPreview(_ layer: AVCaptureVideoPreviewLayer) async {
        await cameraActor.attachPreview(layer)
    }

    func detachPreview(_ layer: AVCaptureVideoPreviewLayer) async {
        await cameraActor.detachPreview(layer)
    }
}
