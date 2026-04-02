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
    @Environment(\.colorScheme) private var colorScheme

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
        .onChange(of: colorScheme) {
            updateSceneBackground()
        }
    }

    private func loadPLYFile() async {
        isLoading = true
        errorMessage = nil

        let url = await PLYStore.shared.localURL(for: plyID)
        self.plyFileURL = url

        do {
            let pointCloud = try PLYParser.parse(url: url)
            scene = PLYParser.makeScene(from: pointCloud)
            updateSceneBackground()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func updateSceneBackground() {
        let color: UIColor = colorScheme == .dark
            ? UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
            : .white
        scene?.background.contents = color
    }
}

#Preview {
    NavigationStack {
        PLYViewerView(plyID: "test", filename: "test.ply")
    }
}