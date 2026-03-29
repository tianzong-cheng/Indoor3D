// Indoor3D/Features/Gallery/PLYListView.swift

import SwiftUI

struct PLYListView: View {
    @StateObject private var viewModel = PLYListViewModel()
    @State private var selectedFile: PLYFile?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if viewModel.plyFiles.isEmpty {
                    ContentUnavailableView(
                        "No Reconstructions",
                        systemImage: "cube.transparent",
                        description: Text("No 3D models available yet")
                    )
                } else {
                    List(viewModel.plyFiles) { file in
                        PLYFileRow(
                            file: file,
                            isDownloaded: viewModel.downloadedIDs.contains(file.id),
                            locationText: viewModel.locationText(for: file),
                            sizeText: viewModel.formattedSize(file.fileSizeMb),
                            dateText: viewModel.formattedDate(file.createdAt),
                            onDownload: { Task { await viewModel.downloadPLY(file) } },
                            onDelete: { Task { await viewModel.deleteLocalPLY(file) } },
                            onView: { selectedFile = file }
                        )
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("3D Reconstructions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.loadPLYFiles() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .navigationDestination(item: $selectedFile) { file in
                if viewModel.downloadedIDs.contains(file.id) {
                    PLYViewerView(plyID: file.id, filename: file.filename)
                }
            }
        }
        .task {
            await viewModel.loadPLYFiles()
        }
    }
}

struct PLYFileRow: View {
    let file: PLYFile
    let isDownloaded: Bool
    let locationText: String
    let sizeText: String
    let dateText: String
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onView: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "building.2")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(locationText)
                    .font(.headline)

                Text("\(sizeText) • Updated \(dateText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if isDownloaded {
                    Button("View 3D") { onView() }
                        .buttonStyle(.borderedProminent)

                    Menu {
                        Button("Delete Local Copy", role: .destructive) { onDelete() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                } else {
                    Button("Download") { onDownload() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PLYListView()
}