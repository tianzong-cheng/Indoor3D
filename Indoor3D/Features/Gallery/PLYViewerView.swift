// Indoor3D/Features/Gallery/PLYViewerView.swift

import SceneKit
import SwiftUI

struct PLYViewerView: View {
    let plyID: String
    let filename: String

    @State private var scene: SCNScene?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var plyFileURL: URL?

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading 3D model...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let scene = scene {
                SceneView(
                    scene: scene,
                    pointOfView: scene.rootNode.childNode(withName: "camera", recursively: true),
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
            }
        }
        .navigationTitle(filename)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = plyFileURL {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: url)
                }
            }
        }
        .task {
            await loadPLYFile()
        }
    }

    private func loadPLYFile() async {
        isLoading = true
        errorMessage = nil

        let url = await PLYStore.shared.localURL(for: plyID)
        self.plyFileURL = url

        do {
            let newScene = try SCNScene(url: url, options: nil)

            // Add a camera if not present
            if newScene.rootNode.childNode(withName: "camera", recursively: true) == nil {
                let cameraNode = SCNNode()
                cameraNode.camera = SCNCamera()
                cameraNode.position = SCNVector3(0, 0, 5)
                cameraNode.name = "camera"
                newScene.rootNode.addChildNode(cameraNode)
            }

            // Center the model
            let boundingBox = newScene.rootNode.boundingBox
            let center = SCNVector3(
                (boundingBox.min.x + boundingBox.max.x) / 2,
                (boundingBox.min.y + boundingBox.max.y) / 2,
                (boundingBox.min.z + boundingBox.max.z) / 2
            )

            for child in newScene.rootNode.childNodes {
                child.position = SCNVector3(
                    child.position.x - center.x,
                    child.position.y - center.y,
                    child.position.z - center.z
                )
            }

            scene = newScene
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        PLYViewerView(plyID: "test", filename: "test.ply")
    }
}