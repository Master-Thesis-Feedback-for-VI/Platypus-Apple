//
//  ReplayItem.swift
//  Platypus
//
//  Created by Yann Bernard on 23.09.26.
//

import Foundation
import ZIPFoundation

final class ReplayItem: Identifiable {
    let id = UUID()
    let absolutPath: URL

    private var tempPath: URL?

    init(path: URL) {
        self.absolutPath = path
    }
}

extension ReplayItem {
    var title: String {
        let stem = absolutPath.deletingPathExtension().lastPathComponent
        return stem.localizedCapitalized
    }
    
    func videoPath() async throws -> URL {
        let dir = try await self.resolvedTempPath()
        return dir.appendingPathComponent("recording.mov")
    }
    
    func contentPath() async throws -> URL {
        let dir = try await self.resolvedTempPath()
        return dir.appendingPathComponent("content.json")
    }
    
    func intoVideoPlayback() async throws -> VideoPlayback {
        let videoPath = try await self.videoPath()
        let eval = try await self.evaluations()
        let videoPlayback = VideoPlayback(evaluations: eval, videoPath: videoPath)
        return videoPlayback
    }

    func evaluations() async throws -> [ImageFlowEvaluationForRecording] {
        let contentFile = try await self.contentPath()
        return try await imageFlowEvaluationReadFromJson(path: contentFile.path)
    }

    private func resolvedTempPath() async throws -> URL {
        if let tempPath {
            return tempPath
        }
        let dir = try await Self.unpack(absolutPath, id: id)
        tempPath = dir
        return dir
    }

    private static func unpack(_ source: URL, id: UUID) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let fileManager = FileManager.default
                let tmpDir = fileManager.temporaryDirectory
                    .appendingPathComponent(id.uuidString, isDirectory: true)

                do {
                    if fileManager.fileExists(atPath: tmpDir.path) {
                        try fileManager.removeItem(at: tmpDir)
                    }
                    try fileManager.createDirectory(
                        at: tmpDir,
                        withIntermediateDirectories: true
                    )
                    try fileManager.unzipItem(at: source, to: tmpDir)
                    continuation.resume(returning: tmpDir)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
