//
//  Indoor3DApp.swift
//  Indoor3D
//
//  Created by 程天纵 on 2026/3/27.
//

import SwiftUI

@main
struct Indoor3DApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Record", systemImage: "video.fill") {
                RecordingView()
            }

            Tab("Upload Queue", systemImage: "arrow.up.circle.fill") {
                UploadQueueView()
            }

            Tab("Gallery", systemImage: "cube.transparent") {
                PLYListView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}