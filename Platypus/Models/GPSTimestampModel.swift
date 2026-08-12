//
//  GPSTimestampModel.swift
//  Platypus
//
//  Created by Yann Bernard on 11.08.26.
//

import CoreLocation
import MetaCodable
import CodableCSV

@Codable
@CodingKeys(.snake_case)
struct GPSTimestampModel {
    let timestamp: UInt64
    let latitude: Float16
    let longitude: Float16
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
        self.timestamp = UInt64(Date().timeIntervalSince1970)
        self.latitude = Float16(location.latitude)
        self.longitude = Float16(location.longitude)
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
        return try csvData().base64EncodedString(options: .lineLength76Characters)
    }
    
    func writeCsv(to url: URL) throws {
        try csvData().write(to: url)
    }
    
    mutating func flush(to url: URL) throws {
        guard !stamps.isEmpty else { return }
        
        let fileExists = FileManager.default.fileExists(atPath: url.path)
        let encoder = CSVEncoder {
            $0.headers = fileExists ? [] : ["timestamp", "latitude", "longitude"]
        }
        let newData = try encoder.encode(stamps, into: Data.self)

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
