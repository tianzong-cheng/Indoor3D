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