// Indoor3D/Core/Network/Endpoints.swift

import Foundation

nonisolated struct Endpoints {
    static let baseURL = URL(string: "http://localhost:8000/api/v1")!

    static var videos: URL { baseURL.appendingPathComponent("videos") }
    static var plyFiles: URL { baseURL.appendingPathComponent("ply-files") }

    static func plyFile(id: String) -> URL {
        baseURL.appendingPathComponent("ply-files").appendingPathComponent(id)
    }
}