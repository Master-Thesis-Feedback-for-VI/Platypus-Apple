//
//  CameraManager.swift
//  Platypus
//
//  Created by Yann Bernard on 11.08.26.
//

import Foundation
import Combine
import AVFoundation

class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    static let CAMERA_DOMAIN: String = "\(DOMAIN).video.session"
    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()
    
    let session = AVCaptureSession()
    
    private let videoOutput = AVCaptureMovieFileOutput()
    
    @Published var isCamAuthorized: Bool = false
    @Published var capturedVideo: Data?
    @Published var capturedVideoURL: URL?
    @Published var recordingError: Error?
    @Published var isRecording = false
    
    private let sessionQueue = DispatchQueue(label: CAMERA_DOMAIN)
    var fileBundle = FileBundler(createDir: false)
    
    override init() {
        super.init()
        
        checkPermissions()
    }
    
    // MARK: - Permissions
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isCamAuthorized = true
            self.setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isCamAuthorized = granted
                    if granted { self?.setupCamera() }
                }
            }
        default:
            self.isCamAuthorized = false
        }
    }
    
    // MARK: - Camera Setup
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
             
            self.session.beginConfiguration()
             
            // a. Find the device (Default rear camera)
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("No camera was found")
                self.session.commitConfiguration()
                return
            }
             
            // b. Create the input
            do {
                let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.session.canAddInput(videoDeviceInput) {
                    self.session.addInput(videoDeviceInput)
                }
            } catch {
                print("Error creating input: \(error.localizedDescription)")
                self.session.commitConfiguration()
                return
            }
             
            // c. Create the video output
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
             
            self.session.commitConfiguration()
        }
    }
    
    // MARK: - Session Control
    func startSession() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    // MARK: - Video Capture
    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self, !self.videoOutput.isRecording else { return }

            self.fileBundle = FileBundler()
                
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.videoOutput.startRecording(
                    to: fileBundle.videoFile,
                    recordingDelegate: self
                )
            }
        }
    }
    
    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self, self.videoOutput.isRecording else { return }
            self.videoOutput.stopRecording()
            fileBundle.saveBundled()
        }
    }
    
    // MARK: - Save the file
    @MainActor
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async {
            if let error {
                self.recordingError = error
                self.isRecording = false
                return
            }

            self.capturedVideoURL = outputFileURL
            self.isRecording = false

            do {
                self.capturedVideo = try Data(contentsOf: outputFileURL)
            } catch {
                self.recordingError = error
            }
        }
    }
    
    @MainActor
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
}
