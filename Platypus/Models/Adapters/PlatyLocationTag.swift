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
    init?(from uniqueLocationTags: UniqueLocationTags) {
        let categories = sortLocationTags(
            categories: Array(uniqueLocationTags.categories)
        ).compactMap { tag in
            let desc = String(describing: tag).capitalized
            return PlatyLocationTag(rawValue: desc)
        }

        guard let category = categories.first else { return nil }
        self = category
    }

    func localizedName(in language: AppLanguage) -> String {
        language.localized(rawValue)
    }
}

extension PlatyLocationTag: DisplayableProto {
    var displayName: String {
        AppLanguage.current.localized(englishName)
    }

    private var englishName: String {
        switch self {
        case .forest: return "Forest"
        case .outside: return "Outside"
        case .inside: return "Inside"
        case .street: return "Street"
        case .parking: return "Parking"
        case .railway: return "Railway"
        }
    }

    var symbolName: String {
        switch self {
        case .forest: return "tree.fill"
        case .outside: return "sun.max.fill"
        case .inside: return "house.fill"
        case .street: return "road.lanes"
        case .parking: return "parkingsign.square.fill"
        case .railway: return "lightrail"
        }
    }
}

extension UniqueLocationTags {
    func asPlatyLocationTags() -> [PlatyLocationTag] {
        let items = sortLocationTags(
            categories: Array(self.categories)
        )
        return items.compactMap { tag in
            let desc = String(describing: tag).capitalized
            return PlatyLocationTag(rawValue: desc)
        }
    }
}
