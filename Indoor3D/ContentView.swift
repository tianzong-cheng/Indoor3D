//
//  ContentView.swift
//  Indoor3D
//
//  Created by 程天纵 on 2026/3/27.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Indoor3D")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Contribute to indoor 3D maps\nby recording videos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                FeatureRow(icon: "video.fill", title: "Record", description: "Capture indoor spaces with AR guidance")
                FeatureRow(icon: "arrow.up.circle.fill", title: "Upload", description: "Queue and upload multiple videos")
                FeatureRow(icon: "cube.transparent", title: "Explore", description: "View 3D reconstructions")
            }
            .padding()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    ContentView()
}