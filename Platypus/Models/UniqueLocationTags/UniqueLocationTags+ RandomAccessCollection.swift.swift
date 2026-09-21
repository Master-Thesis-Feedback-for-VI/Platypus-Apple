//
//  UniqueLocationTags+Sequence.swift
//  Platypus
//
//  Created by Yann Bernard on 21.09.26.
//

extension UniqueLocationTags: RandomAccessCollection {
    public typealias Element = LocationTag
    public typealias Index = Int

    private var sortedCategories: [LocationTag] {
        categories.sorted { $0.displayName < $1.displayName }
    }

    public var startIndex: Int { sortedCategories.startIndex }
    public var endIndex: Int { sortedCategories.endIndex }

    public func index(after i: Int) -> Int {
        sortedCategories.index(after: i)
    }

    public subscript(index: Int) -> LocationTag {
        sortedCategories[index]
    }
}
