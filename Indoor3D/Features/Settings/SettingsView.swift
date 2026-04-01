import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("Video Storage", systemImage: "internaldrive")
                        Spacer()
                        Text(viewModel.storageUsed)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Videos Saved", systemImage: "video.fill")
                        Spacer()
                        Text("\(viewModel.videoCount)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Storage")
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Label("Delete All Videos", systemImage: "trash")
                            Spacer()
                            if viewModel.isCleaning {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.videoCount == 0 || viewModel.isCleaning)
                } footer: {
                    Text("This will remove all locally saved videos. Videos already uploaded to the server will not be affected.")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                viewModel.refreshStorageInfo()
            }
            .alert("Delete All Videos?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    viewModel.deleteAllVideos()
                }
            } message: {
                Text("This will permanently delete \(viewModel.videoCount) video(s) from this device. This action cannot be undone.")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

#Preview {
    SettingsView()
}
