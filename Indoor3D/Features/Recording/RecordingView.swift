// Indoor3D/Features/Recording/RecordingView.swift

import AVFoundation
import SwiftUI

struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showMetadataSheet = false
    @State private var buildingName = ""
    @State private var floor = ""
    @State private var cameraReady = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                // Camera preview + overlays fade in together
                Group {
                    // Camera preview
                    CameraPreview(session: viewModel.captureSession)
                        .ignoresSafeArea()

                    // Recording indicator
                    if viewModel.state == .recording {
                        VStack {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)
                                Text(viewModel.formattedDuration)
                                    .font(.system(.title2, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            Spacer()
                        }
                    }

                    // Motion feedback overlay
                    if let feedback = viewModel.motionFeedback,
                       let message = feedback.message {
                        VStack {
                            Spacer()
                            Text(message)
                                .font(.headline)
                                .foregroundColor(feedbackColor(for: feedback.state))
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                                .padding(.bottom, 150)
                        }
                    }

                    // Controls
                    VStack {
                        Spacer()
                        HStack(spacing: 40) {
                            switch viewModel.state {
                            case .idle, .preparing:
                                Button(action: { viewModel.startRecording() }) {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 70, height: 70)
                                        .overlay(
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 60, height: 60)
                                        )
                                }

                            case .recording:
                                Button(action: { viewModel.stopRecording() }) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red)
                                        .frame(width: 50, height: 50)
                                }

                            case .stopped:
                                EmptyView()
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
                .opacity(cameraReady ? 1 : 0)
            }
        }
        .onAppear {
            cameraReady = false
            viewModel.setupCaptureSession()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeIn(duration: 0.3)) {
                    cameraReady = true
                }
            }
        }
        .onDisappear {
            cameraReady = false
            viewModel.stopSession()
        }
        .onChange(of: viewModel.state) {
            if viewModel.state == .stopped {
                showMetadataSheet = true
            }
        }
        .sheet(isPresented: $showMetadataSheet) {
            MetadataSheetView(
                buildingName: $buildingName,
                floor: $floor,
                onSave: { saveVideoWithMetadata() },
                onSkip: { saveVideoWithMetadata() }
            )
        }
    }

    private func feedbackColor(for state: MotionState) -> Color {
        switch state {
        case .good:
            return .green
        case .tooFast, .shaky:
            return .yellow
        case .tooSlow:
            return .orange
        }
    }

    private func saveVideoWithMetadata() {
        showMetadataSheet = false

        guard let videoURL = viewModel.currentVideoURL else { return }

        Task {
            let metadata = VideoMetadata(
                id: UUID(),
                filename: "\(UUID().uuidString).mov",
                createdAt: Date(),
                latitude: nil, // Will be set by location manager
                longitude: nil,
                altitude: nil,
                buildingName: buildingName.isEmpty ? nil : buildingName,
                floor: floor.isEmpty ? nil : Int(floor),
                duration: viewModel.duration
            )

            _ = try? await VideoStore.shared.saveVideo(from: videoURL, metadata: metadata)
            await UploadService.shared.addToQueue(videoMetadata: metadata)

            viewModel.state = .idle
            viewModel.duration = 0
            buildingName = ""
            floor = ""
        }
    }
}

struct MetadataSheetView: View {
    @Binding var buildingName: String
    @Binding var floor: String
    let onSave: () -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Location Details (Optional)") {
                    TextField("Building Name", text: $buildingName)
                    TextField("Floor Number", text: $floor)
                        .keyboardType(.numberPad)
                }
            }
            .presentationDetents([.medium])
            .navigationTitle("Video Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { onSkip() }
                }
            }
        }
    }
}

final class _CameraPreviewView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        (layer.sublayers?.first(where: { $0.name == "previewLayer" }) as? AVCaptureVideoPreviewLayer)?.frame = bounds
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> _CameraPreviewView {
        let view = _CameraPreviewView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: _CameraPreviewView, context: Context) {
        let existingLayer = uiView.layer.sublayers?.first(where: { $0.name == "previewLayer" }) as? AVCaptureVideoPreviewLayer

        if let session {
            if let existingLayer {
                existingLayer.session = session
            } else {
                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.frame = uiView.bounds
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.name = "previewLayer"
                uiView.layer.addSublayer(previewLayer)
            }
        } else {
            existingLayer?.removeFromSuperlayer()
        }
    }
}