// Indoor3D/Core/Rendering/PLYParser.swift

import Foundation
import SceneKit
import UIKit

struct PLYPointCloud {
    let vertices: [SCNVector3]
    let colors: [UIColor]
    let boundingBox: (min: SCNVector3, max: SCNVector3)
}

enum PLYParseError: LocalizedError {
    case fileNotFound
    case invalidHeader
    case unsupportedFormat
    case readError(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound: "PLY file not found"
        case .invalidHeader: "Invalid PLY header"
        case .unsupportedFormat: "Only binary_little_endian PLY with vertex x,y,z + RGB is supported"
        case .readError(let msg): "PLY read error: \(msg)"
        }
    }
}

struct PLYParser {

    static func parse(url: URL) throws -> PLYPointCloud {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PLYParseError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        let (vertexCount, headerLength) = try parseHeader(data)

        // Each vertex: 3 floats (x,y,z) + 3 bytes (r,g,b) = 15 bytes
        let bytesPerVertex = 3 * MemoryLayout<Float>.size + 3
        let expectedSize = headerLength + vertexCount * bytesPerVertex
        guard data.count >= expectedSize else {
            throw PLYParseError.readError("File too short: expected \(expectedSize) bytes, got \(data.count)")
        }

        var vertices = [SCNVector3]()
        var colors = [UIColor]()
        vertices.reserveCapacity(vertexCount)
        colors.reserveCapacity(vertexCount)

        var minX: Float = .infinity, minY: Float = .infinity, minZ: Float = .infinity
        var maxX: Float = -.infinity, maxY: Float = -.infinity, maxZ: Float = -.infinity

        data[headerLength..<data.count].withUnsafeBytes { rawBuffer in
            let buffer = rawBuffer.bindMemory(to: UInt8.self)

            for i in 0..<vertexCount {
                let offset = i * bytesPerVertex

                var x: Float = 0, y: Float = 0, z: Float = 0
                _ = withUnsafeMutableBytes(of: &x) { buffer[offset..<(offset + 4)].copyBytes(to: $0) }
                _ = withUnsafeMutableBytes(of: &y) { buffer[(offset + 4)..<(offset + 8)].copyBytes(to: $0) }
                _ = withUnsafeMutableBytes(of: &z) { buffer[(offset + 8)..<(offset + 12)].copyBytes(to: $0) }

                let r = buffer[offset + 12]
                let g = buffer[offset + 13]
                let b = buffer[offset + 14]

                let vertex = SCNVector3(x, y, z)
                vertices.append(vertex)
                colors.append(UIColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: 1.0))

                minX = min(minX, x); minY = min(minY, y); minZ = min(minZ, z)
                maxX = max(maxX, x); maxY = max(maxY, y); maxZ = max(maxZ, z)
            }
        }

        return PLYPointCloud(
            vertices: vertices,
            colors: colors,
            boundingBox: (min: SCNVector3(minX, minY, minZ), max: SCNVector3(maxX, maxY, maxZ))
        )
    }

    private static func parseHeader(_ data: Data) throws -> (vertexCount: Int, headerLength: Int) {
        let headerEndMarker = Data("end_header\n".utf8)
        guard let headerEndRange = data.range(of: headerEndMarker) else {
            throw PLYParseError.invalidHeader
        }

        let headerString = String(data: data[..<headerEndRange.lowerBound], encoding: .ascii) ?? ""
        let headerLength = headerEndRange.upperBound

        var vertexCount = 0
        var format: String?

        for line in headerString.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("format") {
                format = trimmed
            } else if trimmed.hasPrefix("element vertex") {
                let parts = trimmed.split(separator: " ")
                if parts.count >= 3, let count = Int(parts[2]) {
                    vertexCount = count
                }
            }
        }

        guard let fmt = format, fmt.contains("binary_little_endian") else {
            throw PLYParseError.unsupportedFormat
        }
        guard vertexCount > 0 else {
            throw PLYParseError.invalidHeader
        }

        return (vertexCount, headerLength)
    }

    static func makeScene(from pointCloud: PLYPointCloud) -> SCNScene {
        let scene = SCNScene()
        let vertexCount = pointCloud.vertices.count

        let positions = NSData(bytes: pointCloud.vertices, length: vertexCount * MemoryLayout<SCNVector3>.size) as NSData

        var colorComponents = [Float]()
        colorComponents.reserveCapacity(vertexCount * 4)
        for color in pointCloud.colors {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            colorComponents.append(contentsOf: [Float(r), Float(g), Float(b), Float(a)])
        }
        let colorsData = NSData(bytes: colorComponents, length: vertexCount * 4 * MemoryLayout<Float>.size) as NSData

        let source = SCNGeometrySource(data: positions as Data,
                                       semantic: .vertex,
                                       vectorCount: vertexCount,
                                       usesFloatComponents: true,
                                       componentsPerVector: 3,
                                       bytesPerComponent: MemoryLayout<Float>.size,
                                       dataOffset: 0,
                                       dataStride: MemoryLayout<SCNVector3>.size)

        let colorSource = SCNGeometrySource(data: colorsData as Data,
                                            semantic: .color,
                                            vectorCount: vertexCount,
                                            usesFloatComponents: true,
                                            componentsPerVector: 4,
                                            bytesPerComponent: MemoryLayout<Float>.size,
                                            dataOffset: 0,
                                            dataStride: 4 * MemoryLayout<Float>.size)

        // Use implicit sequential indices (no explicit index buffer)
        let element = SCNGeometryElement(data: nil,
                                         primitiveType: .point,
                                         primitiveCount: vertexCount,
                                         bytesPerIndex: 0)

        // Set point size
        element.pointSize = 1.0
        element.minimumPointScreenSpaceRadius = 1.0
        element.maximumPointScreenSpaceRadius = 4.0

        let geometry = SCNGeometry(sources: [source, colorSource], elements: [element])
        geometry.firstMaterial?.lightingModel = .constant

        let node = SCNNode(geometry: geometry)

        // Center the point cloud
        let bb = pointCloud.boundingBox
        let center = SCNVector3(
            (bb.min.x + bb.max.x) / 2,
            (bb.min.y + bb.max.y) / 2,
            (bb.min.z + bb.max.z) / 2
        )
        node.position = SCNVector3(-center.x, -center.y, -center.z)

        // Wrap geometry in a rotation node for auto-rotation
        let rotationNode = SCNNode()
        rotationNode.name = "rotationNode"
        rotationNode.addChildNode(node)
        scene.rootNode.addChildNode(rotationNode)

        // Add camera at 45-degree elevation
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.name = "camera"

        // Position camera to see the whole point cloud
        let extent = SCNVector3(
            bb.max.x - bb.min.x,
            bb.max.y - bb.min.y,
            bb.max.z - bb.min.z
        )
        let maxExtent = max(extent.x, extent.y, extent.z)
        let distance = Float(maxExtent) * 1.5
        let elevationAngle = Float.pi / 4 // 45 degrees
        cameraNode.position = SCNVector3(
            0,
            distance * sin(elevationAngle),
            distance * cos(elevationAngle)
        )
        // Orient camera to look at the center
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        return scene
    }
}
