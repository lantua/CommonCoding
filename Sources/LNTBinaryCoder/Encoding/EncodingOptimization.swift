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
    var tag: Header.Tag?

    for value in values {
        var current: Header.Tag
        switch value {
        case is NilOptimizableStorage: current = .nil
        case is FixedWidthOptimizableStorage: current = .fixedWidth
        case is StringOptimizableStorage: current = .stringReference
        default: return nil // Unsupported types
        }

        if tag == nil {
            tag = current
        }

        guard tag == current else {
            // Non-uniform array
            return nil
        }
    }

    switch tag {
    case nil: return nil
    case .nil: return (0, .nil)
    case .fixedWidth: return (values.lazy.map { $0.size }.reduce(0, max), .fixedWidth)
    case .stringReference: return (values.lazy.map { $0.size }.reduce(0, max), .stringReference)
    default: fatalError("Unreachable")
    }
}
