//
//  SingleStorage.swift
//  
//
//  Created by Natchanon Luangsomboon on 20/2/2563 BE.
//

import Foundation

struct NilOptimizableStorage: EncodingStorage {
    var header: Header { .nil }
    var payloadSize: Int { 0 }

    func optimize(for context: OptimizationContext) { }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) { }
}

struct FixedWidthOptimizableStorage: EncodingStorage {
    let raw: Data

    var header: Header { .fixedWidth }
    var payloadSize: Int { raw.count }

    func optimize(for context: OptimizationContext) { }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) {
        assert(data.count >= raw.count)
        raw.copyBytes(to: UnsafeMutableRawBufferPointer(rebasing: data))
    }
}

struct StringOptimizableStorage: EncodingStorage {
    private let string: String
    private var index = 0

    var header: Header { .stringReference }
    var payloadSize: Int { index.vsuiSize }

    init(string: String) {
        self.string = string
    }

    mutating func optimize(for context: OptimizationContext) {
        index = context.index(for: string)
    }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) {
        var data = data
        index.write(to: &data)
    }
}
