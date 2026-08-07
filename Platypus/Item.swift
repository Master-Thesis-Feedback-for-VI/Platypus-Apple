//
//  Item.swift
//  Platypus
//
//  Created by Yann Bernard on 07.08.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
