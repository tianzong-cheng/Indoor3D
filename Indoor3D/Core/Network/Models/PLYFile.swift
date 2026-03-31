// Indoor3D/Core/Network/Models/PLYFile.swift

import Foundation

nonisolated struct PLYFile: Codable, Hashable, Identifiable {
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

nonisolated struct PLYListResponse: Codable {
    let plyFiles: [PLYFile]

    enum CodingKeys: String, CodingKey {
        case plyFiles = "ply_files"
    }
}