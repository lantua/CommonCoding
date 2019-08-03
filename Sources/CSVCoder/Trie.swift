//
//  Trie.swift
//  CSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

struct Trie<Value> {
    private var children: [String: Trie] = [:]
    private(set) var value: Value?
    
    var keys: Dictionary<String, Trie>.Keys { return children.keys }
    
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
}
