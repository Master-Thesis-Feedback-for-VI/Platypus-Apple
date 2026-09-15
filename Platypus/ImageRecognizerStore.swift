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

    func load() async {
        let dlPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!.path

        do {
            recognizer = try await ImageRecognizer(
                modelVariant: .medium,
                downlaodPath: dlPath
            )
        } catch {
            loadError = error
        }
    }
}
