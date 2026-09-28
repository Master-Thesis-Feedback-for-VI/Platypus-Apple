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
    private var imageProperties: [CFString: Any]? {
        guard let source = CGImageSourceCreateWithData(img as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any]
        else { return nil }
        return properties
    }

    // The Rust image decoder reads the JPEG's raw pixels, without applying EXIF orientation.
    var pixelSize: CGSize? {
        guard let properties = imageProperties,
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else { return nil }
        return CGSize(width: width, height: height)
    }

    var detectionTransform: CGAffineTransform {
        guard let size = pixelSize else { return .identity }
        let width = size.width
        let height = size.height
        let orientation = (imageProperties?[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1

        switch orientation {
        case 2: return CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0)
        case 3: return CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: width, ty: height)
        case 4: return CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        case 5: return CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        case 6: return CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: height, ty: 0)
        case 7: return CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: height, ty: width)
        case 8: return CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: width)
        default: return .identity
        }
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
