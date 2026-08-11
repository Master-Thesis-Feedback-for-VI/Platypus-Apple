//
//  FileBundler.swift
//  Platypus
//
//  Created by Yann Bernard on 11.08.26.
//

import Foundation
import ZIPFoundation

struct FileBundler {
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
    
    let dirName: String
    
    init(createDir: Bool = true) {
        let fileManager = FileManager.default
        
        let path = "recording-\(Self.fileNameFormatter.string(from: Date()))"
        self.dirName = path
//        let dirPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
//            .appendingPathComponent(path)
        let dirPath = fileManager.temporaryDirectory.appendingPathComponent(path)
        
        if createDir && !fileManager.fileExists(atPath: dirPath.path) {
            try! fileManager.createDirectory(at: dirPath, withIntermediateDirectories: true, attributes: nil)
        }
        
        self.bundleDirPath = dirPath
        self.videoFile = dirPath.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
    }
    
    func saveBundled() {
        let fileManager = FileManager.default
        let targetPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(self.dirName)
            .appendingPathExtension("zip")
        
        try! fileManager.zipItem(at: self.bundleDirPath, to: targetPath)
    }
}


