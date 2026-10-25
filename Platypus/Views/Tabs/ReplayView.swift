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
            .background(AppTheme.background)
            .navigationTitle(AppLanguage.current.localized("Available Videos"))
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
            let fm = FileManager.default
            let documentsUrl = fm.urls(
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

                var filteredFiles = try fm.contentsOfDirectory(
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

                if await !PlatypusApp.isUITesting {
                    let defaultReplays =
                        Bundle.main.urls(
                            forResourcesWithExtension: "zip",
                            subdirectory: "Replays"
                        ) ?? []
                    filteredFiles += defaultReplays
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
                    .foregroundStyle(AppTheme.text)

                Text(verbatim: replayItem.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
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
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(Text(verbatim: replayItem.title))
        .fullScreenCover(item: $evaluationData) { data in
            VideoPlaybackView(playback: data)
                .highContrastTheme()
        }
    }
}

#Preview {
    ReplayView()
}
