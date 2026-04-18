// Indoor3D/Features/Upload/UploadQueueView.swift

import SwiftUI

struct UploadQueueView: View {
    @StateObject private var viewModel = UploadQueueViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "No Videos",
                        systemImage: "video.slash",
                        description: Text("Record a video to see it here")
                    )
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            UploadQueueItemRow(
                                item: item,
                                locationText: viewModel.formattedLocation(for: item),
                                statusText: viewModel.statusText(for: item),
                                onRetry: { Task { await viewModel.retry(item) } },
                                onRemove: { Task { await viewModel.remove(item) } }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Upload Queue")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.loadItems() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await viewModel.loadItems()
        }
    }
}

struct UploadQueueItemRow: View {
    let item: UploadQueueItem
    let locationText: String
    let statusText: String
    let onRetry: () -> Void
    let onRemove: () -> Void

    private var recordedAtText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: item.videoMetadata.createdAt, relativeTo: Date())
    }

    var body: some View {
        HStack {
            Image(systemName: "video.fill")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(locationText)
                    .font(.headline)

                Text(recordedAtText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            if item.status == .failed {
                Button("Retry") { onRetry() }
                    .buttonStyle(.bordered)
            } else if item.status == .completed {
                Button("Clear") { onRemove() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    var statusColor: Color {
        switch item.status {
        case .pending:
            return .secondary
        case .uploading:
            return .blue
        case .paused:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

#Preview {
    UploadQueueView()
}