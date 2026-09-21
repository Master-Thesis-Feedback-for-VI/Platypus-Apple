//
//  DisplayableProto.swift
//  Platypus
//
//  Created by Yann Bernard on 21.09.26.
//

protocol DisplayableProto {
    var displayName: String { get }
    var symbolName: String { get }
    var displayTitle: String { get }
}

extension DisplayableProto {
    var displayTitle: String {
        displayName
    }
}
