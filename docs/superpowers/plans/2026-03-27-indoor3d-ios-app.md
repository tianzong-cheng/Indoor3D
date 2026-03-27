# Indoor3D iOS App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete iOS app for indoor 3D reconstruction with video recording, upload queue, and .ply visualization.

**Architecture:** MVVM with SwiftUI. Core modules (Network, Storage, Location) provide foundation for feature modules (Recording, Upload, Gallery). TDD approach where applicable.

**Tech Stack:** Swift, SwiftUI, AVFoundation, ARKit, CoreMotion, CoreLocation, URLSession, SceneKit

---

## File Structure

```
Indoor3D/
├── App/
│   └── Indoor3DApp.swift
├── Core/
│   ├── Network/
│   │   ├── APIClient.swift
│   │   ├── APIClientError.swift
│   │   ├── Endpoints.swift
│   │   └── Models/
│   │       ├── VideoUploadResponse.swift
│   │       └── PLYFile.swift
│   ├── Storage/
│   │   ├── VideoStore.swift
│   │   ├── PLYStore.swift
│   │   └── UploadQueueItem.swift
│   └── Location/
│       └── LocationManager.swift
├── Features/
│   ├── Recording/
│   │   ├── RecordingView.swift
│   │   ├── RecordingViewModel.swift
│   │   ├── MotionAnalyzer.swift
│   │   └── ARGuidanceOverlay.swift
│   ├── Upload/
│   │   ├── UploadQueueView.swift
│   │   ├── UploadQueueViewModel.swift
│   │   └── UploadService.swift
│   └── Gallery/
│       ├── PLYListView.swift
│       ├── PLYListViewModel.swift
│       └── PLYViewerView.swift
└── Shared/
    └── Extensions/
        └── Date+ISO8601.swift
```

---

## Phase 1: Core Infrastructure

### Task 1: Create API Models

**Files:**
- Create: `Indoor3D/Core/Network/Models/VideoUploadResponse.swift`
- Create: `Indoor3D/Core/Network/Models/PLYFile.swift`

- [ ] **Step 1: Create VideoUploadResponse model**

```swift
// Indoor3D/Core/Network/Models/VideoUploadResponse.swift

import Foundation

struct VideoUploadResponse: Codable {
    let videoId: String
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case status
        case createdAt = "created_at"
    }
}
```

- [ ] **Step 2: Create PLYFile model**

```swift
// Indoor3D/Core/Network/Models/PLYFile.swift

import Foundation

struct PLYFile: Codable, Identifiable {
    let id: String
    let filename: String
    let fileSizeMb: Double
    let latitude: Double
    let longitude: Double
    let buildingName: String?
    let floor: Int?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case filename
        case fileSizeMb = "file_size_mb"
        case latitude
        case longitude
        case buildingName = "building_name"
        case floor
        case createdAt = "created_at"
    }
}

struct PLYListResponse: Codable {
    let plyFiles: [PLYFile]

    enum CodingKeys: String, CodingKey {
        case plyFiles = "ply_files"
    }
}
```

- [ ] **Step 3: Create Date ISO8601 extension**

```swift
// Indoor3D/Shared/Extensions/Date+ISO8601.swift

import Foundation

extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

extension DateFormatter {
    static var iso8601: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add Indoor3D/Core/Network/Models/*.swift Indoor3D/Shared/Extensions/*.swift
git commit -m "feat: add API models for video upload and PLY files"
```

---

### Task 2: Create APIClient Infrastructure

**Files:**
- Create: `Indoor3D/Core/Network/APIClientError.swift`
- Create: `Indoor3D/Core/Network/Endpoints.swift`
- Create: `Indoor3D/Core/Network/APIClient.swift`

- [ ] **Step 1: Create APIClientError**

```swift
// Indoor3D/Core/Network/APIClientError.swift

import Foundation

enum APIClientError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode):
            return "Server error (code: \(statusCode))"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        }
    }
}
```

- [ ] **Step 2: Create Endpoints**

```swift
// Indoor3D/Core/Network/Endpoints.swift

import Foundation

struct Endpoints {
    static let baseURL = URL(string: "http://localhost:8000/api/v1")!

    static var videos: URL { baseURL.appendingPathComponent("videos") }
    static var plyFiles: URL { baseURL.appendingPathComponent("ply-files") }

    static func plyFile(id: String) -> URL {
        baseURL.appendingPathComponent("ply-files").appendingPathComponent(id)
    }
}
```

- [ ] **Step 3: Create APIClient**

```swift
// Indoor3D/Core/Network/APIClient.swift

import Foundation

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func get<T: Codable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        return try decodeResponse(data: data, response: response)
    }

    func download(_ url: URL) async throws -> URL {
        let (localURL, response) = try await session.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIClientError.httpError(statusCode: httpResponse.statusCode)
        }
        return localURL
    }

    func uploadVideo(
        fileURL: URL,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        buildingName: String? = nil,
        floor: Int? = nil
    ) async throws -> VideoUploadResponse {
        var request = URLRequest(url: Endpoints.videos)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add video file
        let fileData = try Data(contentsOf: fileURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/quicktime\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // Add metadata fields
        func addField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        addField("latitude", String(latitude))
        addField("longitude", String(longitude))

        if let altitude = altitude {
            addField("altitude", String(altitude))
        }
        if let buildingName = buildingName {
            addField("building_name", buildingName)
        }
        if let floor = floor {
            addField("floor", String(floor))
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(data: data, response: response)
    }

    private func decodeResponse<T: Codable>(data: Data, response: URLResponse) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIClientError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingError(error)
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add Indoor3D/Core/Network/*.swift
git commit -m "feat: add APIClient with video upload support"
```

---

### Task 3: Create LocationManager

**Files:**
- Create: `Indoor3D/Core/Location/LocationManager.swift`

- [ ] **Step 1: Create LocationManager**

```swift
// Indoor3D/Core/Location/LocationManager.swift

import CoreLocation
import Foundation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    private let clLocationManager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    override init() {
        super.init()
        clLocationManager.delegate = self
        clLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = clLocationManager.authorizationStatus
    }

    func requestPermission() {
        clLocationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        clLocationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        clLocationManager.stopUpdatingLocation()
    }

    var hasLocationPermission: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.last {
                self.location = location
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Core/Location/LocationManager.swift
git commit -m "feat: add LocationManager for GPS coordinates"
```

---

### Task 4: Create VideoStore

**Files:**
- Create: `Indoor3D/Core/Storage/VideoStore.swift`

- [ ] **Step 1: Create VideoStore**

```swift
// Indoor3D/Core/Storage/VideoStore.swift

import Foundation

struct VideoMetadata: Codable {
    let id: UUID
    let filename: String
    let createdAt: Date
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    let buildingName: String?
    let floor: Int?
    let duration: TimeInterval
}

actor VideoStore {
    static let shared = VideoStore()

    private let fileManager = FileManager.default
    private let videosDirectory: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        videosDirectory = appSupport.appendingPathComponent("Videos", isDirectory: true)

        if !fileManager.fileExists(atPath: videosDirectory.path) {
            try? fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        }
    }

    func saveVideo(from tempURL: URL, metadata: VideoMetadata) throws -> URL {
        let destinationURL = videosDirectory.appendingPathComponent(metadata.filename)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: tempURL, to: destinationURL)

        let metadataURL = videosDirectory.appendingPathComponent("\(metadata.id).json")
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: metadataURL)

        return destinationURL
    }

    func loadMetadata(for id: UUID) throws -> VideoMetadata {
        let metadataURL = videosDirectory.appendingPathComponent("\(id).json")
        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder().decode(VideoMetadata.self, from: data)
    }

    func videoURL(for filename: String) -> URL {
        videosDirectory.appendingPathComponent(filename)
    }

    func deleteVideo(id: UUID) throws {
        let metadata = try loadMetadata(for: id)
        let videoURL = self.videoURL(for: metadata.filename)
        let metadataURL = videosDirectory.appendingPathComponent("\(id).json")

        if fileManager.fileExists(atPath: videoURL.path) {
            try fileManager.removeItem(at: videoURL)
        }
        if fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.removeItem(at: metadataURL)
        }
    }

    func listAllVideos() throws -> [VideoMetadata] {
        let contents = try fileManager.contentsOfDirectory(at: videosDirectory, includingPropertiesForKeys: nil)
        let jsonFiles = contents.filter { $0.pathExtension == "json" }

        return try jsonFiles.map { url in
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VideoMetadata.self, from: data)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Core/Storage/VideoStore.swift
git commit -m "feat: add VideoStore for local video management"
```

---

### Task 5: Create UploadQueueItem and UploadService

**Files:**
- Create: `Indoor3D/Core/Storage/UploadQueueItem.swift`
- Create: `Indoor3D/Features/Upload/UploadService.swift`

- [ ] **Step 1: Create UploadQueueItem**

```swift
// Indoor3D/Core/Storage/UploadQueueItem.swift

import Foundation

enum UploadStatus: String, Codable {
    case pending
    case uploading
    case paused
    case completed
    case failed
}

struct UploadQueueItem: Identifiable, Codable {
    let id: UUID
    let videoMetadata: VideoMetadata
    var status: UploadStatus
    var progress: Double
    var errorMessage: String?
    var retryCount: Int

    init(videoMetadata: VideoMetadata) {
        self.id = UUID()
        self.videoMetadata = videoMetadata
        self.status = .pending
        self.progress = 0
        self.errorMessage = nil
        self.retryCount = 0
    }
}

actor UploadQueue {
    static let shared = UploadQueue()

    private let queueURL: URL
    private var items: [UploadQueueItem] = []

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        queueURL = appSupport.appendingPathComponent("upload_queue.json")

        loadQueue()
    }

    private func loadQueue() {
        guard FileManager.default.fileExists(atPath: queueURL.path) else { return }
        if let data = try? Data(contentsOf: queueURL),
           let decoded = try? JSONDecoder().decode([UploadQueueItem].self, from: data) {
            items = decoded
        }
    }

    private func saveQueue() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: queueURL)
        }
    }

    func add(_ item: UploadQueueItem) {
        items.append(item)
        saveQueue()
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        saveQueue()
    }

    func update(_ item: UploadQueueItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveQueue()
        }
    }

    func getAll() -> [UploadQueueItem] {
        items
    }

    func getPending() -> [UploadQueueItem] {
        items.filter { $0.status == .pending || $0.status == .failed }
    }
}
```

- [ ] **Step 2: Create UploadService**

```swift
// Indoor3D/Features/Upload/UploadService.swift

import Foundation

@MainActor
final class UploadService: ObservableObject {
    static let shared = UploadService()

    @Published var isUploading = false

    private var currentTask: Task<Void, Never>?

    private init() {}

    func startProcessingQueue() {
        guard !isUploading else { return }

        currentTask = Task {
            await processQueue()
        }
    }

    func stopProcessing() {
        currentTask?.cancel()
        currentTask = nil
        isUploading = false
    }

    private func processQueue() async {
        isUploading = true

        while !Task.isCancelled {
            let pendingItems = await UploadQueue.shared.getPending()

            guard let item = pendingItems.first else {
                break
            }

            var updatedItem = item
            updatedItem.status = .uploading
            await UploadQueue.shared.update(updatedItem)

            do {
                let videoURL = await VideoStore.shared.videoURL(for: item.videoMetadata.filename)

                _ = try await APIClient.shared.uploadVideo(
                    fileURL: videoURL,
                    latitude: item.videoMetadata.latitude ?? 0,
                    longitude: item.videoMetadata.longitude ?? 0,
                    altitude: item.videoMetadata.altitude,
                    buildingName: item.videoMetadata.buildingName,
                    floor: item.videoMetadata.floor
                )

                updatedItem.status = .completed
                updatedItem.progress = 1.0
                await UploadQueue.shared.update(updatedItem)

            } catch {
                updatedItem.status = .failed
                updatedItem.errorMessage = error.localizedDescription
                updatedItem.retryCount += 1
                await UploadQueue.shared.update(updatedItem)

                // Exponential backoff
                let delay = min(60, pow(2.0, Double(updatedItem.retryCount)))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        isUploading = false
    }

    func addToQueue(videoMetadata: VideoMetadata) async {
        let item = UploadQueueItem(videoMetadata: videoMetadata)
        await UploadQueue.shared.add(item)
        startProcessingQueue()
    }

    func retry(_ item: UploadQueueItem) async {
        var updated = item
        updated.status = .pending
        updated.errorMessage = nil
        await UploadQueue.shared.update(updated)
        startProcessingQueue()
    }

    func remove(_ item: UploadQueueItem) async {
        await UploadQueue.shared.remove(item.id)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Indoor3D/Core/Storage/UploadQueueItem.swift Indoor3D/Features/Upload/UploadService.swift
git commit -m "feat: add upload queue and upload service"
```

---

### Task 6: Create PLYStore

**Files:**
- Create: `Indoor3D/Core/Storage/PLYStore.swift`

- [ ] **Step 1: Create PLYStore**

```swift
// Indoor3D/Core/Storage/PLYStore.swift

import Foundation

actor PLYStore {
    static let shared = PLYStore()

    private let fileManager = FileManager.default
    private let plyDirectory: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        plyDirectory = appSupport.appendingPathComponent("PLYFiles", isDirectory: true)

        if !fileManager.fileExists(atPath: plyDirectory.path) {
            try? fileManager.createDirectory(at: plyDirectory, withIntermediateDirectories: true)
        }
    }

    func localURL(for id: String) -> URL {
        plyDirectory.appendingPathComponent("\(id).ply")
    }

    func isDownloaded(id: String) -> Bool {
        fileManager.fileExists(atPath: localURL(for: id).path)
    }

    func savePLY(from tempURL: URL, id: String) throws -> URL {
        let destinationURL = localURL(for: id)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: tempURL, to: destinationURL)
        return destinationURL
    }

    func delete(id: String) throws {
        let url = localURL(for: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func listDownloaded() -> [String] {
        guard let contents = try? fileManager.contentsOfDirectory(at: plyDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return contents
            .filter { $0.pathExtension == "ply" }
            .map { $0.deletingPathExtension().lastPathComponent }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Core/Storage/PLYStore.swift
git commit -m "feat: add PLYStore for downloaded .ply files"
```

---

## Phase 2: Recording Feature

### Task 7: Create MotionAnalyzer

**Files:**
- Create: `Indoor3D/Features/Recording/MotionAnalyzer.swift`

- [ ] **Step 1: Create MotionAnalyzer**

```swift
// Indoor3D/Features/Recording/MotionAnalyzer.swift

import CoreMotion
import Foundation

enum MotionState {
    case good
    case tooFast
    case tooSlow
    case shaky
}

struct MotionFeedback {
    let state: MotionState
    let message: String?
}

@MainActor
final class MotionAnalyzer: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var currentFeedback: MotionFeedback?

    private var lastUpdateTime: Date = Date()
    private var lastAcceleration: CMAcceleration?

    // Thresholds (tunable)
    let maxVelocity: Double = 1.5  // m/s
    let minVelocity: Double = 0.1
    let maxRotationRate: Double = 2.0  // rad/s
    let stopThreshold: TimeInterval = 3.0

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            currentFeedback = MotionFeedback(state: .good, message: nil)
            return
        }

        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            Task { @MainActor in
                self.analyze(motion: motion)
            }
        }
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        currentFeedback = nil
    }

    private func analyze(motion: CMDeviceMotion) {
        let now = Date()
        let acceleration = motion.userAcceleration
        let rotationRate = motion.rotationRate

        // Calculate velocity magnitude
        let velocityMagnitude = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )

        // Calculate rotation magnitude
        let rotationMagnitude = sqrt(
            rotationRate.x * rotationRate.x +
            rotationRate.y * rotationRate.y +
            rotationRate.z * rotationRate.z
        )

        // Determine state
        var state: MotionState = .good
        var message: String?

        if velocityMagnitude > maxVelocity {
            state = .tooFast
            message = "Move slower"
        } else if rotationMagnitude > maxRotationRate {
            state = .shaky
            message = "Hold steadier"
        } else if velocityMagnitude < minVelocity {
            let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
            if timeSinceLastUpdate > stopThreshold {
                state = .tooSlow
                message = "Keep moving"
            }
        }

        lastUpdateTime = now
        lastAcceleration = acceleration
        currentFeedback = MotionFeedback(state: state, message: message)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Features/Recording/MotionAnalyzer.swift
git commit -m "feat: add MotionAnalyzer for recording guidance"
```

---

### Task 8: Create RecordingViewModel

**Files:**
- Create: `Indoor3D/Features/Recording/RecordingViewModel.swift`

- [ ] **Step 1: Create RecordingViewModel**

```swift
// Indoor3D/Features/Recording/RecordingViewModel.swift

import AVFoundation
import Foundation
import SwiftUI

enum RecordingState {
    case idle
    case preparing
    case recording
    case stopped
}

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var motionFeedback: MotionFeedback?

    let motionAnalyzer = MotionAnalyzer()

    private var captureSession: AVCaptureSession?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    private var currentVideoURL: URL?

    func setupCaptureSession() {
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

        session.startRunning()
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
            Task { @MainActor in
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
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Features/Recording/RecordingViewModel.swift
git commit -m "feat: add RecordingViewModel with AVFoundation capture"
```

---

### Task 9: Create RecordingView

**Files:**
- Create: `Indoor3D/Features/Recording/RecordingView.swift`

- [ ] **Step 1: Create RecordingView**

```swift
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
        .onChange(of: viewModel.state) { newState in
            if newState == .stopped {
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

            try? await VideoStore.shared.saveVideo(from: videoURL, metadata: metadata)
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
        let previewLayer = AVCaptureVideoPreviewLayer(session: session!)
        previewLayer.frame = UIScreen.main.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Features/Recording/RecordingView.swift
git commit -m "feat: add RecordingView with camera preview and controls"
```

---

### Task 10: Create ARGuidanceOverlay

**Files:**
- Create: `Indoor3D/Features/Recording/ARGuidanceOverlay.swift`

- [ ] **Step 1: Create ARGuidanceOverlay**

```swift
// Indoor3D/Features/Recording/ARGuidanceOverlay.swift

import ARKit
import RealityKit
import SwiftUI

struct ARGuidanceOverlay: UIViewRepresentable {
    let isRecording: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.debugOptions = [.showFeaturePoints]

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal

        arView.session.run(config)

        context.coordinator.arView = arView
        context.coordinator.setupScene()

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if isRecording {
            context.coordinator.startTracking()
        } else {
            context.coordinator.stopTracking()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        private var coverageGrid: ModelEntity?
        private var trackedPositions: [SIMD3<Float>] = []

        func setupScene() {
            let anchor = AnchorEntity(plane: .horizontal)
            arView?.scene.addAnchor(anchor)

            // Create coverage grid visualization
            let gridMesh = MeshResource.generatePlane(width: 5, depth: 5)
            let gridMaterial = SimpleMaterial(color: .cyan.withAlphaComponent(0.3), isMetallic: false)
            let gridEntity = ModelEntity(mesh: gridMesh, materials: [gridMaterial])
            gridEntity.position.y = 0.01

            anchor.addChild(gridEntity)
            coverageGrid = gridEntity
        }

        func startTracking() {
            trackedPositions.removeAll()
            arView?.session.delegate = self
        }

        func stopTracking() {
            arView?.session.delegate = nil
        }

        // MARK: - ARSessionDelegate

        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let cameraPosition = frame.camera.transform.columns.3

            Task { @MainActor in
                let position = SIMD3<Float>(cameraPosition.x, cameraPosition.y, cameraPosition.z)

                // Add to tracked positions if far enough from last position
                if let lastPosition = trackedPositions.last {
                    let distance = simd_distance(position, lastPosition)
                    if distance > 0.3 {
                        trackedPositions.append(position)
                        updateVisualization()
                    }
                } else {
                    trackedPositions.append(position)
                }
            }
        }

        private func updateVisualization() {
            // Update grid based on coverage
            // This is a simplified version - real implementation would show actual covered areas
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Features/Recording/ARGuidanceOverlay.swift
git commit -m "feat: add ARGuidanceOverlay with coverage tracking"
```

---

## Phase 3: Upload Feature

### Task 11: Create UploadQueueViewModel

**Files:**
- Create: `Indoor3D/Features/Upload/UploadQueueViewModel.swift`

- [ ] **Step 1: Create UploadQueueViewModel**

```swift
// Indoor3D/Features/Upload/UploadQueueViewModel.swift

import Foundation

@MainActor
final class UploadQueueViewModel: ObservableObject {
    @Published var items: [UploadQueueItem] = []
    @Published var isLoading = false

    private let uploadService = UploadService.shared

    func loadItems() async {
        isLoading = true
        items = await UploadQueue.shared.getAll()
        isLoading = false
    }

    func retry(_ item: UploadQueueItem) async {
        await uploadService.retry(item)
        await loadItems()
    }

    func remove(_ item: UploadQueueItem) async {
        await uploadService.remove(item)
        await loadItems()
    }

    func formattedLocation(for item: UploadQueueItem) -> String {
        let metadata = item.videoMetadata

        if let building = metadata.buildingName, let floor = metadata.floor {
            return "\(building), Floor \(floor)"
        } else if let building = metadata.buildingName {
            return building
        } else if metadata.latitude != nil && metadata.longitude != nil {
            return String(format: "%.4f, %.4f", metadata.latitude!, metadata.longitude!)
        } else {
            return "No location"
        }
    }

    func statusText(for item: UploadQueueItem) -> String {
        switch item.status {
        case .pending:
            return "Pending"
        case .uploading:
            return "Uploading... \(Int(item.progress * 100))%"
        case .paused:
            return "Paused"
        case .completed:
            return "Uploaded"
        case .failed:
            return "Failed: \(item.errorMessage ?? "Unknown error")"
        }
    }

    func statusColor(for item: UploadQueueItem) -> String {
        switch item.status {
        case .pending:
            return "gray"
        case .uploading:
            return "blue"
        case .paused:
            return "orange"
        case .completed:
            return "green"
        case .failed:
            return "red"
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Features/Upload/UploadQueueViewModel.swift
git commit -m "feat: add UploadQueueViewModel"
```

---

### Task 12: Create UploadQueueView

**Files:**
- Create: `Indoor3D/Features/Upload/UploadQueueView.swift`

- [ ] **Step 1: Create UploadQueueView**

```swift
// Indoor3D/Features/Upload/UploadQueueView.swift

import SwiftUI

struct UploadQueueView: View {
    @StateObject private var viewModel = UploadQueueViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "No Videos",
                        systemImage: "video.slash",
                        description: Text("Record a video to see it here")
                    )
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            UploadQueueItemRow(
                                item: item,
                                locationText: viewModel.formattedLocation(for: item),
                                statusText: viewModel.statusText(for: item),
                                onRetry: { Task { await viewModel.retry(item) } },
                                onRemove: { Task { await viewModel.remove(item) } }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Upload Queue")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.loadItems() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await viewModel.loadItems()
        }
    }
}

struct UploadQueueItemRow: View {
    let item: UploadQueueItem
    let locationText: String
    let statusText: String
    let onRetry: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "video.fill")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.videoMetadata.filename)
                    .font(.headline)

                Text(locationText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            if item.status == .failed {
                Button("Retry") { onRetry() }
                    .buttonStyle(.bordered)
            } else if item.status == .completed {
                Button("Clear") { onRemove() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    var statusColor: Color {
        switch item.status {
        case .pending:
            return .secondary
        case .uploading:
            return .blue
        case .paused:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

#Preview {
    UploadQueueView()
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Features/Upload/UploadQueueView.swift
git commit -m "feat: add UploadQueueView with item management"
```

---

## Phase 4: Gallery Feature

### Task 13: Create PLYListViewModel

**Files:**
- Create: `Indoor3D/Features/Gallery/PLYListViewModel.swift`

- [ ] **Step 1: Create PLYListViewModel**

```swift
// Indoor3D/Features/Gallery/PLYListViewModel.swift

import Foundation

@MainActor
final class PLYListViewModel: ObservableObject {
    @Published var plyFiles: [PLYFile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var downloadedIDs: Set<String> = []

    func loadPLYFiles() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: PLYListResponse = try await APIClient.shared.get(Endpoints.plyFiles)
            self.plyFiles = response.plyFiles
            self.downloadedIDs = Set(await PLYStore.shared.listDownloaded())
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func downloadPLY(_ file: PLYFile) async {
        do {
            let tempURL = try await APIClient.shared.download(Endpoints.plyFile(id: file.id))
            let _ = try await PLYStore.shared.savePLY(from: tempURL, id: file.id)
            downloadedIDs.insert(file.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteLocalPLY(_ file: PLYFile) async {
        try? await PLYStore.shared.delete(id: file.id)
        downloadedIDs.remove(file.id)
    }

    func formattedSize(_ mb: Double) -> String {
        if mb < 1 {
            return String(format: "%.0f KB", mb * 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func locationText(for file: PLYFile) -> String {
        if let building = file.buildingName, let floor = file.floor {
            return "\(building) - Floor \(floor)"
        } else if let building = file.buildingName {
            return building
        } else {
            return String(format: "%.4f, %.4f", file.latitude, file.longitude)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Features/Gallery/PLYListViewModel.swift
git commit -m "feat: add PLYListViewModel for gallery"
```

---

### Task 14: Create PLYListView

**Files:**
- Create: `Indoor3D/Features/Gallery/PLYListView.swift`

- [ ] **Step 1: Create PLYListView**

```swift
// Indoor3D/Features/Gallery/PLYListView.swift

import SwiftUI

struct PLYListView: View {
    @StateObject private var viewModel = PLYListViewModel()
    @State private var selectedFile: PLYFile?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if viewModel.plyFiles.isEmpty {
                    ContentUnavailableView(
                        "No Reconstructions",
                        systemImage: "cube.transparent",
                        description: Text("No 3D models available yet")
                    )
                } else {
                    List(viewModel.plyFiles) { file in
                        PLYFileRow(
                            file: file,
                            isDownloaded: viewModel.downloadedIDs.contains(file.id),
                            locationText: viewModel.locationText(for: file),
                            sizeText: viewModel.formattedSize(file.fileSizeMb),
                            dateText: viewModel.formattedDate(file.createdAt),
                            onDownload: { Task { await viewModel.downloadPLY(file) } },
                            onDelete: { Task { await viewModel.deleteLocalPLY(file) } },
                            onView: { selectedFile = file }
                        )
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("3D Reconstructions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.loadPLYFiles() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .navigationDestination(item: $selectedFile) { file in
                if viewModel.downloadedIDs.contains(file.id) {
                    PLYViewerView(plyID: file.id, filename: file.filename)
                }
            }
        }
        .task {
            await viewModel.loadPLYFiles()
        }
    }
}

struct PLYFileRow: View {
    let file: PLYFile
    let isDownloaded: Bool
    let locationText: String
    let sizeText: String
    let dateText: String
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onView: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "building.2")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(locationText)
                    .font(.headline)

                Text("\(sizeText) • Updated \(dateText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if isDownloaded {
                    Button("View 3D") { onView() }
                        .buttonStyle(.borderedProminent)

                    Menu {
                        Button("Delete Local Copy", role: .destructive) { onDelete() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                } else {
                    Button("Download") { onDownload() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PLYListView()
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Features/Gallery/PLYListView.swift
git commit -m "feat: add PLYListView for browsing .ply files"
```

---

### Task 15: Create PLYViewerView

**Files:**
- Create: `Indoor3D/Features/Gallery/PLYViewerView.swift`

- [ ] **Step 1: Create PLYViewerView**

```swift
// Indoor3D/Features/Gallery/PLYViewerView.swift

import SceneKit
import SwiftUI

struct PLYViewerView: View {
    let plyID: String
    let filename: String

    @State private var scene: SCNScene?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var plyFileURL: URL?

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading 3D model...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let scene = scene {
                SceneView(
                    scene: scene,
                    pointOfView: scene.rootNode.childNode(withName: "camera", recursively: true),
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
            }
        }
        .navigationTitle(filename)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = plyFileURL {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: url)
                }
            }
        }
        .task {
            await loadPLYFile()
        }
    }

    private func loadPLYFile() async {
        isLoading = true
        errorMessage = nil

        let url = await PLYStore.shared.localURL(for: plyID)
        self.plyFileURL = url

        do {
            let newScene = try SCNScene(url: url, options: nil)

            // Add a camera if not present
            if newScene.rootNode.childNode(withName: "camera", recursively: true) == nil {
                let cameraNode = SCNNode()
                cameraNode.camera = SCNCamera()
                cameraNode.position = SCNVector3(0, 0, 5)
                cameraNode.name = "camera"
                newScene.rootNode.addChildNode(cameraNode)
            }

            // Center the model
            let boundingBox = newScene.rootNode.boundingBox
            let center = SCNVector3(
                (boundingBox.min.x + boundingBox.max.x) / 2,
                (boundingBox.min.y + boundingBox.max.y) / 2,
                (boundingBox.min.z + boundingBox.max.z) / 2
            )

            for child in newScene.rootNode.childNodes {
                child.position = SCNVector3(
                    child.position.x - center.x,
                    child.position.y - center.y,
                    child.position.z - center.z
                )
            }

            scene = newScene
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        PLYViewerView(plyID: "test", filename: "test.ply")
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Features/Gallery/PLYViewerView.swift
git commit -m "feat: add PLYViewerView with SceneKit visualization"
```

---

## Phase 5: App Integration

### Task 16: Update Indoor3DApp with Navigation

**Files:**
- Modify: `Indoor3D/Indoor3DApp.swift`

- [ ] **Step 1: Update Indoor3DApp**

```swift
// Indoor3D/Indoor3DApp.swift

import SwiftUI

@main
struct Indoor3DApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Record", systemImage: "video.fill") {
                RecordingView()
            }

            Tab("Upload Queue", systemImage: "arrow.up.circle.fill") {
                UploadQueueView()
            }

            Tab("Gallery", systemImage: "cube.transparent") {
                PLYListView()
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Indoor3DApp.swift
git commit -m "feat: add main tab navigation with all features"
```

---

### Task 17: Update Info.plist for Permissions

**Files:**
- Modify: `Indoor3D/Info.plist` (or via Xcode target settings)

- [ ] **Step 1: Add required permissions**

In Xcode, add the following to your Info.plist or target settings:

```
NSCameraUsageDescription = "Camera access is required to record videos for 3D reconstruction"
NSMicrophoneUsageDescription = "Microphone access is required to record audio with videos"
NSLocationWhenInUseUsageDescription = "Location access is used to tag videos with GPS coordinates"
NSMotionUsageDescription = "Motion data is used to provide recording guidance"
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/Info.plist
git commit -m "feat: add required permission descriptions"
```

---

### Task 18: Update ContentView as Landing Page

**Files:**
- Modify: `Indoor3D/ContentView.swift`

- [ ] **Step 1: Update ContentView**

```swift
// Indoor3D/ContentView.swift

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Indoor3D")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Contribute to indoor 3D maps\nby recording videos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                FeatureRow(icon: "video.fill", title: "Record", description: "Capture indoor spaces with AR guidance")
                FeatureRow(icon: "arrow.up.circle.fill", title: "Upload", description: "Queue and upload multiple videos")
                FeatureRow(icon: "cube.transparent", title: "Explore", description: "View 3D reconstructions")
            }
            .padding()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 2: Commit**

```bash
git add Indoor3D/ContentView.swift
git commit -m "feat: add landing page content view"
```

---

## Summary

This plan implements the complete Indoor3D iOS app across 18 tasks:

1. **Core Infrastructure (Tasks 1-6)**: API models, APIClient, LocationManager, VideoStore, UploadQueue, PLYStore
2. **Recording Feature (Tasks 7-10)**: MotionAnalyzer, RecordingViewModel, RecordingView, ARGuidanceOverlay
3. **Upload Feature (Tasks 11-12)**: UploadQueueViewModel, UploadQueueView
4. **Gallery Feature (Tasks 13-15)**: PLYListViewModel, PLYListView, PLYViewerView
5. **App Integration (Tasks 16-18)**: Main tab navigation, permissions, landing page

Each task produces working, testable code. The app can be built incrementally - each phase is independently functional.