//
//  Trie.swift
//  CSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

struct Trie<Value> {
    private(set) var children: [String: Trie] = [:]
    private(set) var value: Value?
    
    subscript(key: CodingKey) -> Trie? {
        return children[key.stringValue]
    }
    
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

    func contains(predicate: (Value) throws -> Bool) rethrows -> Bool {
        if let value = value,
            try predicate(value) {
            return true
        }

        return try children.values.contains { try $0.contains(predicate: predicate) }
    }
}
