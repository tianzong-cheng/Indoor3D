// Indoor3D/Features/Recording/ARGuidanceOverlay.swift

import ARKit
import RealityKit
import SwiftUI

struct ARGuidanceOverlay: UIViewRepresentable {
    let isRecording: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.debugOptions = [.showFeaturePoints]

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal

        arView.session.run(config)

        context.coordinator.arView = arView
        context.coordinator.setupScene()

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if isRecording {
            context.coordinator.startTracking()
        } else {
            context.coordinator.stopTracking()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        private var coverageGrid: ModelEntity?
        private var trackedPositions: [SIMD3<Float>] = []

        func setupScene() {
            let anchor = AnchorEntity(plane: .horizontal)
            arView?.scene.addAnchor(anchor)

            // Create coverage grid visualization
            let gridMesh = MeshResource.generatePlane(width: 5, depth: 5)
            let gridMaterial = SimpleMaterial(color: .cyan.withAlphaComponent(0.3), isMetallic: false)
            let gridEntity = ModelEntity(mesh: gridMesh, materials: [gridMaterial])
            gridEntity.position.y = 0.01

            anchor.addChild(gridEntity)
            coverageGrid = gridEntity
        }

        func startTracking() {
            trackedPositions.removeAll()
            arView?.session.delegate = self
        }

        func stopTracking() {
            arView?.session.delegate = nil
        }

        // MARK: - ARSessionDelegate

        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let cameraPosition = frame.camera.transform.columns.3

            Task { @MainActor in
                let position = SIMD3<Float>(cameraPosition.x, cameraPosition.y, cameraPosition.z)

                // Add to tracked positions if far enough from last position
                if let lastPosition = trackedPositions.last {
                    let distance = simd_distance(position, lastPosition)
                    if distance > 0.3 {
                        trackedPositions.append(position)
                        updateVisualization()
                    }
                } else {
                    trackedPositions.append(position)
                }
            }
        }

        private func updateVisualization() {
            // Update grid based on coverage
            // This is a simplified version - real implementation would show actual covered areas
        }
    }
}