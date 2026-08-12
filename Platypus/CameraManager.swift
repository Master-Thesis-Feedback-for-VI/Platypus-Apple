//
//  CameraManager.swift
//  Platypus
//
//  Created by Yann Bernard on 11.08.26.
//
//  Rewritten with structured concurrency for Swift 6 strict-checking mode.
//

import Foundation
import Combine
import AVFoundation

enum CameraError: Error {
    case deviceNotFound
    case alreadyRecording
    case notAuthorized
}

/// Owns the `AVCaptureSession` and every AVFoundation call.
/// Isolating this to its own actor means configuration, start/stop,
/// and recording can never race with each other or with the main actor —
/// the compiler enforces it, so the old `sessionQueue` is no longer needed.
actor CameraSessionActor {
    // AVCaptureSession is documented by Apple as internally thread-safe,
    // which is exactly the situation `nonisolated(unsafe)` exists for:
    // we need synchronous, cross-actor access for an AVCaptureVideoPreviewLayer,
    // and we're deliberately vouching for its safety instead of hiding a race.
    nonisolated(unsafe) let session = AVCaptureSession()

    private let videoOutput = AVCaptureMovieFileOutput()
    private let recordingDelegate = RecordingDelegateProxy()
    
    private var fileBundler = FileBundler(createDir: false)

    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()

    // MARK: - Camera Setup
    func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
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
    func startRecording() async throws -> URL {
        guard !videoOutput.isRecording else { throw CameraError.alreadyRecording }
        
        enum MessageSnapshot {
            case cancel
            case sleepAwake
            case snapNowAndLeave
        }
        
        fileBundler = FileBundler()
        let fileBundlerCpy = fileBundler
        var gpsTimeStamps = GPSTimestamps()
        
        let (snapshotStream, snapshotContinuation) = AsyncStream<MessageSnapshot>.makeStream()
        var work = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [fileBundlerCpy] in
                    let locationModel = LocationViewModel()
                    
                    for await msg in snapshotStream {
                        switch msg {
                        case .cancel:
                            break
                            
                        case .sleepAwake:
                            guard let location = locationModel.location else { continue }
                            let stamp = GPSTimestampModel(location: location)
                            
                            gpsTimeStamps.stamps.append(stamp)
                            if gpsTimeStamps.stamps.count > 10 {
                                _ = try? await gpsTimeStamps.flush(to: fileBundlerCpy.gpsDataFile)
                            }
                            
                        case .snapNowAndLeave:
                            guard let location = locationModel.location else { break }
                            let stamp = GPSTimestampModel(location: location)
                            try? await gpsTimeStamps.flush(to: fileBundlerCpy.gpsDataFile)
                            fileBundlerCpy.saveBundled()
                        }
                    }
                }
                
                group.addTask {
                    while !Task.isCancelled {
                        guard ((try? await Task.sleep(nanoseconds: 500_000)) != nil) else {
                            continue
                        }
                        snapshotContinuation.yield(.sleepAwake)
                    }
                }
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            recordingDelegate.continuation = continuation
            recordingDelegate.onFinish = { [snapshotContinuation] in
                snapshotContinuation.yield(.snapNowAndLeave)
            }
            videoOutput.startRecording(to: fileBundler.videoFile, recordingDelegate: recordingDelegate)
        }
    }

    func stopRecording() {
        guard videoOutput.isRecording else { return }
        videoOutput.stopRecording()
    }
}

/// `AVCaptureFileOutputRecordingDelegate` requires `NSObjectProtocol`
/// conformance, and its callback fires on an AVFoundation-owned thread —
/// not necessarily the actor's executor. Rather than forcing the actor
/// itself to conform, this tiny nonisolated shim just resolves a
/// continuation, which is the pattern recommended for bridging
/// delegate-based AVFoundation APIs into async/await.
nonisolated private final class RecordingDelegateProxy: NSObject, AVCaptureFileOutputRecordingDelegate {
    var continuation: CheckedContinuation<URL, Error>?
    var onFinish: (() -> Void)?

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        if let error {
            continuation?.resume(throwing: error)
        } else {
            onFinish?()
            continuation?.resume(returning: outputFileURL)
        }
        continuation = nil
        onFinish = nil
    }
}

@MainActor
final class CameraManager: ObservableObject {
    private let cameraActor = CameraSessionActor()

    /// Exposed synchronously for SwiftUI preview layers.
    nonisolated var session: AVCaptureSession { cameraActor.session }

    @Published var isCamAuthorized = false
    @Published var capturedVideo: Data?
    @Published var capturedVideoURL: URL?
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
        isRecording = true
        do {
            let url = try await cameraActor.startRecording()
            capturedVideoURL = url
            capturedVideo = try Data(contentsOf: url)
        } catch {
            recordingError = error
        }
        isRecording = false
    }

    func stopRecording() async {
        await cameraActor.stopRecording()
    }
}
