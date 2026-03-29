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