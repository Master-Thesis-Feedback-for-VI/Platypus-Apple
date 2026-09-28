//
//  PlatyImage.swift
//  Platypus
//
//  Created by Yann Bernard on 12.09.26.
//

import AVFoundation
import Combine
import CoreLocation
import Foundation
import ImageIO

struct PlatyImage {
    let img: Data
    public var location: CLLocationCoordinate2D?
}

extension PlatyImage {
    var pixelSize: CGSize? {
        guard let source = CGImageSourceCreateWithData(img as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else { return nil }

        let orientation =
            (properties[kCGImagePropertyOrientation] as? UInt32) ?? 1
        let isRotated90or270 = [5, 6, 7, 8].contains(orientation)

        return isRotated90or270
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
    }

    func saveImage(name named: String) async throws -> URL {
        let fileManager = FileManager.default
        let documentPath = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent(named).appendingPathExtension("jpg")

        try await save(to: documentPath)
        return documentPath
    }

    func saveImage() async throws -> URL {
        let fileManager = FileManager.default
        let documentPath = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension(
                "jpg"
            )

        try await save(to: documentPath)
        return documentPath
    }

    private func save(to url: URL) async throws {
        var data = img
        if let loc = self.location {
            if let embedData = try? embedGPS(loc) {
                data = embedData
            }
        }

        try await Task.detached(priority: .utility) {
            try data.write(to: url, options: .atomic)
        }.value
    }

    // MARK: - Internal functionality
    private func embedGPS(_ location: CLLocationCoordinate2D) throws -> Data {
        guard let source = CGImageSourceCreateWithData(img as CFData, nil),
            let type = CGImageSourceGetType(source)
        else {
            throw CameraError.bundleNotCreated
        }

        var properties =
            (CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [String: Any]) ?? [:]
        properties[kCGImagePropertyGPSDictionary as String] = gpsMetadata(
            for: location
        )

        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output,
                type,
                1,
                nil
            )
        else {
            throw CameraError.bundleNotCreated
        }

        CGImageDestinationAddImageFromSource(
            destination,
            source,
            0,
            properties as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw CameraError.bundleNotCreated
        }

        return output as Data
    }

    private func gpsMetadata(
        for coordinate: CLLocationCoordinate2D,
        date: Date = Date()
    ) -> [String: Any] {
        var gps: [String: Any] = [:]

        gps[kCGImagePropertyGPSLatitude as String] = abs(coordinate.latitude)
        gps[kCGImagePropertyGPSLatitudeRef as String] =
            coordinate.latitude >= 0 ? "N" : "S"
        gps[kCGImagePropertyGPSLongitude as String] = abs(coordinate.longitude)
        gps[kCGImagePropertyGPSLongitudeRef as String] =
            coordinate.longitude >= 0 ? "E" : "W"

        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "HH:mm:ss.ss"
        gps[kCGImagePropertyGPSTimeStamp as String] = formatter.string(
            from: date
        )

        formatter.dateFormat = "yyyy:MM:dd"
        gps[kCGImagePropertyGPSDateStamp as String] = formatter.string(
            from: date
        )

        return gps
    }
}
