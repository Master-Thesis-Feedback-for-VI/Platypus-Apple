//
//  UniqueLocationTags+Codable.swift
//  Platypus
//
//  Created by Yann Bernard on 22.10.26.
//

extension UniqueLocationTags: Codable {
    private enum CodingKeys: String, CodingKey {
        case categories
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categories = try container.decode(
            Set<LocationTag>.self,
            forKey: .categories
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(categories, forKey: .categories)
    }
}

extension LocationTag: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case "railway": self = .railway
        case "street": self = .street
        case "parking": self = .parking
        case "intersection": self = .intersection
        case "pedestrian": self = .pedestrian
        case "forest": self = .forest
        case "outside": self = .outside
        case "inside": self = .inside
        case "elevator": self = .elevator
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown LocationTag: \(value)"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        let value: String

        switch self {
        case .railway: value = "railway"
        case .street: value = "street"
        case .parking: value = "parking"
        case .intersection: value = "intersection"
        case .pedestrian: value = "pedestrian"
        case .forest: value = "forest"
        case .outside: value = "outside"
        case .inside: value = "inside"
        case .elevator: value = "elevator"
        @unknown default:
            throw EncodingError.invalidValue(
                self,
                .init(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unsupported LocationTag"
                )
            )
        }

        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
