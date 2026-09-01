//
//  FileBundler.swift
//  Platypus
//
//  Created by Yann Bernard on 11.08.26.
//

import Foundation
import ZIPFoundation

nonisolated struct FileBundler {
    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()
    
    let bundleDirPath: URL
    
    let videoFile: URL
    let gpsDataFile: URL
    
    let dirName: String

    var archiveFile: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(self.dirName)
            .appendingPathExtension("zip")
    }
    
    init(createDir: Bool = true) {
        let fileManager = FileManager.default
        
        let path = "recording-\(Self.fileNameFormatter.string(from: Date()))"
        self.dirName = path
        let dirPath = fileManager.temporaryDirectory.appendingPathComponent(path)
        
        if createDir && !fileManager.fileExists(atPath: dirPath.path) {
            try! fileManager.createDirectory(at: dirPath, withIntermediateDirectories: true, attributes: nil)
        }
        
        self.bundleDirPath = dirPath
        self.videoFile = dirPath.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        self.gpsDataFile = dirPath.appendingPathComponent("gps_timestamps").appendingPathExtension("csv")
    }
    
    func saveBundled() throws -> URL {
        let fileManager = FileManager.default
        let targetPath = self.archiveFile

        if fileManager.fileExists(atPath: targetPath.path) {
            try fileManager.removeItem(at: targetPath)
        }
        
        try fileManager.zipItem(at: self.bundleDirPath, to: targetPath)
        return targetPath
    }
}

