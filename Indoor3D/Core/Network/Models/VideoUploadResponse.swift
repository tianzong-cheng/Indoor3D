// Indoor3D/Core/Network/Models/VideoUploadResponse.swift

import Foundation

nonisolated struct VideoUploadResponse: Codable {
    let videoId: String
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case status
        case createdAt = "created_at"
    }
}