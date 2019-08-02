//
//  Trie.swift
//  CSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

struct Trie {
    private var children: [String: Trie] = [:]
    var value: Int?
    
    var keys: Dictionary<String, Trie>.Keys { return children.keys }
    
    subscript(key: CodingKey) -> Trie? {
        return children[key.stringValue]
    }
    
    mutating func add(_ value: Int, to path: [String]) -> Bool {
        return add(value, to: path[...])
    }
    
    private mutating func add(_ value: Int, to path: ArraySlice<String>) -> Bool {
        guard let first = path.first else {
            guard self.value == nil else {
                return false
            }
            self.value = value
            return true
        }
        
        return children[first, default: Trie()].add(value, to: path.dropFirst())
    }
}
