//
//  GPSTimestampModel.swift
//  Platypus
//
//  Created by Yann Bernard on 11.08.26.
//

import CoreLocation

struct GPSTimestampModel: Codable {
    let timestamp: Double
    let latitude: Double
    let longitude: Double
}

extension GPSTimestampModel {
    init(location: CLLocationCoordinate2D) {
        self.timestamp = Date().timeIntervalSince1970
        self.latitude = location.latitude
        self.longitude = location.longitude
    }
}

struct GPSTimestamps: Codable {
    var stamps: [GPSTimestampModel]

    init() {
        self.stamps = []
    }
}

extension GPSTimestamps {
    // MARK: - CSV export

    private static let header = "timestamp,latitude,longitude\n"

    private func row(for stamp: GPSTimestampModel) -> String {
        "\(stamp.timestamp),\(stamp.latitude),\(stamp.longitude)\n"
    }

    mutating func flush(to url: URL) throws {
        guard !stamps.isEmpty else { return }

        let fileExists = FileManager.default.fileExists(atPath: url.path)
        var body = ""
        for stamp in stamps { body += row(for: stamp) }
        let newData = Data((fileExists ? body : Self.header + body).utf8)

        if fileExists {
            let handle = try FileHandle(forWritingTo: url)
            defer { handle.closeFile() }
            handle.seekToEndOfFile()
            try handle.write(contentsOf: newData)
        } else {
            try newData.write(to: url, options: .atomic)
        }

        self.stamps.removeAll()
    }
}
