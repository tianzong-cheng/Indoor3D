// Indoor3D/Features/Recording/RecordingView.swift

import AVFoundation
import SwiftUI

struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showMetadataSheet = false
    @State private var buildingName = ""
    @State private var floor = ""

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

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
        }
        .onAppear {
            viewModel.setupCaptureSession()
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

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        guard let session else { return view }
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.name = "previewLayer"
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let session,
              let previewLayer = uiView.layer.sublayers?.first(where: { $0.name == "previewLayer" }) as? AVCaptureVideoPreviewLayer else { return }
        previewLayer.frame = uiView.bounds
        previewLayer.session = session
    }
}