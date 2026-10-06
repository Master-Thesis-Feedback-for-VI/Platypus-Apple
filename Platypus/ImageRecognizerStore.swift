//
//  ImageRecognizerStore.swift
//  Platypus
//
//  Created by Yann Bernard on 15.09.26.
//

import Combine
import Foundation

@MainActor
final class ImageRecognizerStore: ObservableObject {
    @Published private(set) var recognizer: ImageRecognizer?
    @Published var loadError: Error?
    
    private var logger = PlatyLogger(tag: "ImageRecognizerStore")

    func load() async {
        logger.log("Loading image recognizer...")
        let dlPath = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first!.path

        do {
            recognizer = try await ImageRecognizer(
                modelVariant: .medium,
                downlaodPath: dlPath
            )
            logger.log("... loaded recognizer models")

        } catch {
            loadError = error
            logger.log("... failed due to: \(error)", level: .error)
        }
    }
}
