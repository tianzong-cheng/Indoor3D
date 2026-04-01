import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var storageUsed: String = "Calculating..."
    @Published var videoCount: Int = 0
    @Published var isCleaning = false
    @Published var showError = false
    @Published var errorMessage = ""

    func refreshStorageInfo() {
        Task {
            do {
                let size = try await VideoStore.shared.calculateStorageSize()
                let videos = try await VideoStore.shared.listAllVideos()
                storageUsed = size == 0 ? "0 KB" : ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                videoCount = videos.count
            } catch {
                storageUsed = "Unknown"
                videoCount = 0
            }
        }
    }

    func deleteAllVideos() {
        isCleaning = true
        Task {
            do {
                try await VideoStore.shared.deleteAllVideos()
                await UploadQueue.shared.syncWithLocalVideos()
                storageUsed = "0 KB"
                videoCount = 0
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isCleaning = false
        }
    }
}
