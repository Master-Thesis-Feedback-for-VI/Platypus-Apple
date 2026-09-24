//
//  ReplayView.swift
//  Platypus
//
//  Created by Yann Bernard on 21.09.26.
//

import SwiftUI

struct ReplayView: View {
    @State private var replayItems: [ReplayItem] = []

    private var logger = PlatyLogger(tag: "ReplayView")

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(replayItems) { item in
                        FileItemView(replayItem: item)
                    }
                }
                .padding()

            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Available Videos")
            .task {
                await loadReplayItems()
            }
            .refreshable {
                await loadReplayItems()
            }
        }
    }

    func loadReplayItems() async {
        let items = await Task.detached(priority: .userInitiated) {
            [logger] () -> [ReplayItem] in
            let fileManager = FileManager.default
            let documentsUrl = fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )
            .first!
            .appendingPathComponent(
                "simulation_files",
                isDirectory: true
            )

            do {
                try await ensureDirectoryExists(at: documentsUrl)

                let filteredFiles = try fileManager.contentsOfDirectory(
                    at: documentsUrl,
                    includingPropertiesForKeys: [
                        .isRegularFileKey
                    ],
                    options: .skipsHiddenFiles
                )
                .filter { url in
                    url.pathExtension.caseInsensitiveCompare("zip")
                        == .orderedSame
                }

                var results: [ReplayItem] = []
                for url in filteredFiles {
                    await results.append(ReplayItem(path: url))
                }
                return results

            } catch {
                await logger.log("Failure: \(error)", level: .error)
                return []
            }
        }.value

        replayItems = items
    }
}

struct FileItemView: View {
    @State var replayItem: ReplayItem

    @State private var evaluationData: VideoPlayback? = nil
    @State private var isLoading = false
    @State private var loadError: Error?

    private var logger = PlatyLogger(tag: "FileItemView")

    var body: some View {
        Button {
            Task {
                isLoading = true
                defer { isLoading = false }
                
                do {
                    evaluationData = try await replayItem.intoVideoPlayback()
                } catch {
                    logger.log("\(error)", level: .error)
                    loadError = error
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "document")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text(replayItem.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            }
            .padding()
            .background {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    Color(
                        uiColor: .secondarySystemBackground
                    )
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(Color.primary.opacity(0.08), lineWidth: 2)
            }
        }
        .disabled(isLoading)
        .accessibilityLabel(replayItem.title)
        .fullScreenCover(item: $evaluationData) { data in
            VideoPlaybackView(playback: data)
        }
    }
}

#Preview {
    ReplayView()
}
