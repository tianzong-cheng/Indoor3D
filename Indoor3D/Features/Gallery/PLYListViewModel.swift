// Indoor3D/Features/Gallery/PLYListViewModel.swift

import Combine
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
            // Server unavailable — try showing bundled sample for offline testing
            await seedBundledSample()
            self.downloadedIDs = Set(await PLYStore.shared.listDownloaded())

            if downloadedIDs.contains("bundled_sample") {
                self.plyFiles = [PLYFile.sampleFile]
                self.errorMessage = nil
            } else {
                self.errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func seedBundledSample() async {
        let id = "bundled_sample"
        let alreadyDownloaded = await PLYStore.shared.isDownloaded(id: id)
        guard !alreadyDownloaded else { return }

        guard let bundleURL = Bundle.main.url(forResource: "cyberpunk2_combined_pcd", withExtension: "ply") else {
            return
        }
        // Copy bundled file into PLYStore so the viewer can find it
        _ = try? await PLYStore.shared.copyPLY(from: bundleURL, id: id)
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