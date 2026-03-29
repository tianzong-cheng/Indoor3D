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