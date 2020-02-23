//
//  EncodingOptimization.swift
//  
//
//  Created by Natchanon Luangsomboon on 20/2/2563 BE.
//

import Foundation

struct OptimizationContext {
    private var strings: [String: Int] = [:]

    init<C>(strings collection: C) where C: Collection, C.Element == String {
        for (offset, string) in collection.enumerated() {
            strings[string] = offset + 1
        }
    }

    func index(for string: String) -> Int {
        strings[string]!
    }
}

func uniformize<C>(values: C) -> (elementSize: Int, header: Header)? where C: Collection, C.Element == EncodingStorage {
    guard let tag = values.first?.header.tag,
        values.dropFirst().allSatisfy({ $0.header.tag == tag }) else {
            return nil
    }

    switch tag {
    case .nil: return (0, .nil)
    case .signed: return (values.lazy.map { $0.size }.reduce(0, max), .signed)
    case .unsigned: return (values.lazy.map { $0.size }.reduce(0, max), .unsigned)
    case .string: return (values.lazy.map { $0.size }.reduce(0, max), .string)
    default: return nil // Unsupported types
    }
}
