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