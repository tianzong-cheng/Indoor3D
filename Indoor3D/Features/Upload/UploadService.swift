// Indoor3D/Features/Upload/UploadService.swift

import Combine
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
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s delay for demo
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
            updatedItem.progress = 0
            await UploadQueue.shared.update(updatedItem)

            // Simulate upload progress over ~5 seconds
            let totalDuration: Double = 5.0
            let steps = 20
            let stepDuration = totalDuration / Double(steps)
            for step in 1...steps {
                guard !Task.isCancelled else { break }
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                updatedItem.progress = Double(step) / Double(steps)
                await UploadQueue.shared.update(updatedItem)
            }

            guard !Task.isCancelled else { break }

            updatedItem.status = .completed
            updatedItem.progress = 1.0
            await UploadQueue.shared.update(updatedItem)
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