//
//  PlatyLocationTag.swift
//  Platypus
//
//  Created by Yann Bernard on 04.10.26.
//

import Foundation

enum PlatyLocationTag: String, Identifiable, Codable, CaseIterable {
    case inside = "Inside"
    case outside = "Outside"
    case forest = "Forest"
    case street = "Street"
    case parking = "Parking"
    case railway = "Railway"

    var id: Self { self }
}

extension PlatyLocationTag {
    static func from(uniqueLocationTags: UniqueLocationTags) -> Self? {
        let categories = sortLocationTags(
            categories: Array(uniqueLocationTags.categories)
        ).compactMap { tag in
            let desc = String(describing: tag).capitalized
            return PlatyLocationTag(rawValue: desc)
        }

        return categories.first
    }
}
