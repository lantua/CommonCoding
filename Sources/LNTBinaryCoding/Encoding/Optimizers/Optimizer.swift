//
//  EncodingStorage.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation

/// Temporary Storage. Use while in the process of encoding data.
protocol TemporaryEncodingStorage {
    func register(_: EncodingOptimizer)
}

class TopLevelTemporaryEncodingStorage: TemporaryEncodingStorage {
    var value: EncodingOptimizer = NilOptimizer()

    func register(_ newValue: EncodingOptimizer) {
        value = newValue
    }
}

/// Compiled Storage for optimization.
/// Created after the encoding process but before the writing process.
/// Can be optimized to different context.
protocol EncodingOptimizer {
    var header: Header { get }
    var payloadSize: Int { get }
    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>)

    mutating func optimize(for context: OptimizationContext)
}

extension EncodingOptimizer {
    var size: Int { header.size + payloadSize }
    func write(to data: Slice<UnsafeMutableRawBufferPointer>) {
        assert(data.count >= size)

        var data = data
        header.write(to: &data)
        writePayload(to: data)
    }
}

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

func uniformize<C>(values: C) -> (elementSize: Int, header: Header)? where C: Collection, C.Element == EncodingOptimizer {
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
