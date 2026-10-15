//
//  Collectable.swift
//  Platypus
//
//  Created by Yann Bernard on 11.10.26.
//

protocol Collectable<Output>: Sequence {
    associatedtype Output

    func collect() -> Output
}

extension Collectable {
    func collect<C: RangeReplaceableCollection>() -> C
    where C.Element == Element {
        C(self)
    }
}

extension Sequence {
    func collect<C: RangeReplaceableCollection>() -> C
        where C.Element == Element {
        C(self)
    }
}
