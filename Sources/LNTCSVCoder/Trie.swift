//
//  Trie.swift
//  LNTCSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

import LNTCommonCoder

struct Trie<Value> {
    private(set) var children: [String: Trie] = [:]
    private(set) var value: Value?
    
    mutating func add(_ value: Value, to path: [String]) -> Value? {
        return add(value, to: path[...])
    }
    
    private mutating func add(_ value: Value, to path: ArraySlice<String>) -> Value? {
        guard let first = path.first else {
            let oldValue = self.value
            self.value = value
            return oldValue
        }
        
        return children[first, default: Trie()].add(value, to: path.dropFirst())
    }
}

extension Trie where Value == Int {
    func toSchema() throws -> Schema<Value> {
        guard value == nil || children.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Found mixed multi/single field."))
        }

        if let value = value {
            return .init(value: value)
        }

        return try .init(keyed: children.mapValues { try $0.toSchema() })
    }
}
