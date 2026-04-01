// Indoor3D/Core/Storage/VideoStore.swift

import Foundation

nonisolated struct VideoMetadata: Codable {
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

    func videoFileExists(filename: String) -> Bool {
        fileManager.fileExists(atPath: videosDirectory.appendingPathComponent(filename).path)
    }

    func calculateStorageSize() throws -> UInt64 {
        let contents = try fileManager.contentsOfDirectory(at: videosDirectory, includingPropertiesForKeys: [.fileSizeKey])
        return contents.reduce(0) { total, url in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = values.fileSize
            else { return total }
            return total + UInt64(fileSize)
        }
    }

    func deleteAllVideos() throws {
        let contents = try fileManager.contentsOfDirectory(at: videosDirectory, includingPropertiesForKeys: nil)
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
}