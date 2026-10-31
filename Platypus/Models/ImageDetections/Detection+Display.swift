//
//  Detection+Display.swift
//  Platypus
//
//  Created by Yann Bernard on 20.09.26.
//

extension Detection: DisplayableProto {
    var displayName: String {
        AppLanguage.current.localized(englishName)
    }

    private var englishName: String {
        switch name {
        case .person: return "Person"
        case .trafficLight: return "Traffic Light"
        case .car: return "Car"
        case .bicycle: return "Bicycle"
        case .bench: return "Bench"
        case .chair: return "Chair"
        case .diningTable: return "Dining Table"
        case .cup: return "Cup"
        case .handbag: return "Handbag"
        case .laptop: return "Laptop"
        case .tv: return "Tv"
        case .keyboard: return "Keyboard"
        case .unknown: return "Unknown"
        case .cyclist: return "Cyclist"
        case .truck: return "Truck"
        case .motorcycle: return "Motorcycle"
        case .bus: return "Bus"
        }
    }

    var symbolName: String {
        switch name {
        case .person: return "person.fill"
        case .trafficLight: return "figure.walk.diamond"
        case .car: return "car.fill"
        case .bicycle: return "bicycle"
        case .bench: return "chair.lounge.fill"  
        case .chair: return "chair.fill"
        case .diningTable: return "table.fill"
        case .cup: return "cup.and.saucer.fill"
        case .handbag: return "handbag.fill"
        case .laptop: return "laptopcomputer"
        case .tv: return "tv.fill"
        case .keyboard: return "keyboard.fill"
        case .unknown: return "questionmark.square.fill"
        case .cyclist: return "figure.outdoor.cycle"
        case .truck: return "truck.box.fill"
        case .bus: return "bus.fill"
        case .motorcycle: return "motorcycle.fill"
        }
    }
}
