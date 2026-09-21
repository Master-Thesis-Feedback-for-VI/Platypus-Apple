//
//  ContextCategory+Display.swift.swift
//  Platypus
//
//  Created by Yann Bernard on 15.09.26.
//

extension LocationTag: DisplayableProto {
    var displayName: String {
        switch self {
        case .forest: return "Forest"
        case .outside: return "Outside"
        case .inside: return "Inside"
        case .street: return "Street"
        case .pedestrian: return "Pedestrian"
        case .intersection: return "Intersection"
        case .elevator: return "Elevator"
        }
    }

    var symbolName: String {
        switch self {
        case .forest: return "tree.fill"
        case .outside: return "sun.max.fill"
        case .inside: return "house.fill"
        case .street: return "road.lanes"
        case .pedestrian: return "figure.walk"
        case .intersection: return "signpost.right.fill"
        case .elevator: return "arrow.up.arrow.down.square"
        }
    }
}
