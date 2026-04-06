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
    @State private var userHasInteracted = false
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
                ZStack {
                    SceneView(
                        scene: scene,
                        pointOfView: scene.rootNode.childNode(withName: "camera", recursively: true),
                        options: [.allowsCameraControl, .autoenablesDefaultLighting]
                    )
                    if !userHasInteracted {
                        Color.black.opacity(0.001)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        userHasInteracted = true
                                        stopAutoRotation()
                                    }
                            )
                    }
                }
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
            startAutoRotation()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func startAutoRotation() {
        guard let scene,
              let rotationNode = scene.rootNode.childNode(withName: "rotationNode", recursively: true)
        else { return }
        let action = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 20)
        rotationNode.runAction(SCNAction.repeatForever(action), forKey: "autoRotation")
    }

    private func stopAutoRotation() {
        guard let scene,
              let rotationNode = scene.rootNode.childNode(withName: "rotationNode", recursively: true)
        else { return }
        rotationNode.removeAction(forKey: "autoRotation")
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