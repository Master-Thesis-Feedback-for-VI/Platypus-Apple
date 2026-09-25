//
//  PathUtlis.swift
//  Platypus
//
//  Created by Yann Bernard on 23.09.26.
//

import Foundation

enum DirectoryError: Error {
    case pathExistsButIsNotDirectory(URL)
}

func ensureDirectoryExists(at url: URL) throws {
    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false

    let exists = fileManager.fileExists(
        atPath: url.path,
        isDirectory: &isDirectory
    )

    if exists {
        guard isDirectory.boolValue else {
            throw DirectoryError.pathExistsButIsNotDirectory(url)
        }
        return
    }

    try fileManager.createDirectory(
        at: url,
        withIntermediateDirectories: true,
        attributes: nil
    )

    let emptyFilePath = url.appendingPathComponent(".empty")
    try "empty file created".write(
        to: emptyFilePath,
        atomically: true,
        encoding: .utf8
    )
}
