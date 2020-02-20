//
//  Misc.swift
//  LNTBinaryCoder
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

import Foundation

/// Reconstructible coding path.
enum CodingPath {
    case root
    indirect case child(key: CodingKey, parent: CodingPath)

    var codingPath: [CodingKey] {
        switch self {
        case .root: return []
        case let .child(key: key, parent: parent):
            return parent.codingPath + CollectionOfOne(key)
        }
    }
}

struct UnkeyedCodingKey: CodingKey {
    var index: Int

    var intValue: Int? { return index }
    var stringValue: String { return String(index) }

    init(intValue: Int) {
        index = intValue
    }
    init?(stringValue: String) {
        guard let value = Int(stringValue) else {
            return nil
        }
        index = value
    }
}

struct SuperCodingKey: CodingKey {
    var intValue: Int? { return 0 }
    var stringValue: String { return "super" }

    init?(intValue: Int) {
        if intValue != 0 {
            return nil
        }
    }
    init?(stringValue: String) {
        if stringValue != "super" {
            return nil
        }
    }
    init() { }
}
