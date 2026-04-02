// Indoor3D/Features/Recording/RecordingViewModel.swift

@preconcurrency import AVFoundation
import Combine
import Foundation
import SwiftUI

nonisolated enum RecordingState {
    case idle
    case preparing
    case recording
    case stopped
}

@MainActor
final class RecordingViewModel: NSObject, ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var motionFeedback: MotionFeedback?

    let motionAnalyzer = MotionAnalyzer()

    @Published var captureSession: AVCaptureSession?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    private(set) var currentVideoURL: URL?

    func setupCaptureSession() {
        guard captureSession == nil else {
            // Session exists but may be stopped — restart it
            startSession()
            return
        }
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            errorMessage = "Camera not available"
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }

        let audioDevice = AVCaptureDevice.default(for: .audio)
        if let audioDevice = audioDevice,
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        let movieOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        self.captureSession = session
        self.movieFileOutput = movieOutput

        startSession()
    }

    func startSession() {
        guard let captureSession, !captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
            captureSession.startRunning()
        }
    }

    func stopSession() {
        guard let captureSession, captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
            captureSession.stopRunning()
        }
    }

    func startRecording() {
        guard let movieFileOutput = movieFileOutput else { return }

        let documentsPath = FileManager.default.temporaryDirectory
        let videoPath = documentsPath.appendingPathComponent("\(UUID().uuidString).mov")

        movieFileOutput.startRecording(to: videoPath, recordingDelegate: self)

        state = .recording
        recordingStartTime = Date()
        currentVideoURL = videoPath

        motionAnalyzer.startMonitoring()

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateDuration()
            }
        }
    }

    func stopRecording() {
        movieFileOutput?.stopRecording()
        motionAnalyzer.stopMonitoring()
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func updateDuration() {
        guard let startTime = recordingStartTime else { return }
        duration = Date().timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension RecordingViewModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Recording started
    }

    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.state = .idle
                return
            }

            self.currentVideoURL = outputFileURL
            self.state = .stopped
        }
    }
}