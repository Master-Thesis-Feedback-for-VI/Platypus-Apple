//
//  GPSTimestampModel.swift
//  Platypus
//
//  Created by Yann Bernard on 11.08.26.
//

import CodableCSV
import CoreLocation
import MetaCodable

@Codable
@CodingKeys(.snake_case)
struct GPSTimestampModel {
    let timestamp: Double
    let latitude: Double
    let longitude: Double
}

@Codable
@CodingKeys(.snake_case)
struct GPSTimestamps {
    var stamps: [GPSTimestampModel]

    init() {
        self.stamps = []
    }
}

extension GPSTimestampModel {
    init(location: CLLocationCoordinate2D) {
        self.timestamp = Date().timeIntervalSince1970
        self.latitude = location.latitude
        self.longitude = location.longitude
    }
}

extension GPSTimestamps {
    // MARK: - CSV export
    func csvData() throws -> Data {
        let encoder = CSVEncoder {
            $0.headers = ["timestamp", "latitude", "longitude"]
        }

        return try encoder.encode(stamps, into: Data.self)
    }

    func csvString() throws -> String {
        return try csvData().base64EncodedString(
            options: .lineLength76Characters
        )
    }

    func writeCsv(to url: URL) throws {
        try csvData().write(to: url)
    }

    mutating func flush(to url: URL) throws {
        guard !stamps.isEmpty else { return }

        let fileExists = FileManager.default.fileExists(atPath: url.path)
        // The encoder always needs headers to map coding keys to columns;
        // encoding with empty headers throws. When appending to an existing
        // file, the header row is stripped from the encoded data instead.
        let encoder = CSVEncoder {
            $0.headers = ["timestamp", "latitude", "longitude"]
        }
        var newData = try encoder.encode(stamps, into: Data.self)

        if fileExists {
            if let newlineIndex = newData.firstIndex(of: UInt8(ascii: "\n")) {
                newData = newData.subdata(
                    in: newData.index(after: newlineIndex)..<newData.endIndex
                )
            }
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
