//
//  EncodingStorage.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation

/// Temporary Storage. Use while in the process of encoding data.
protocol TemporaryEncodingStorageWriter {
    func register(_: EncodingStorage)
}

class TopLevelTemporaryEncodingStorage: TemporaryEncodingStorageWriter {
    var value: EncodingStorage = NilStorage()

    func register(_ newValue: EncodingStorage) {
        value = newValue
    }
}

/// Compiled Storage.
/// Created after the encoding process but before the writing process.
/// Can be optimized to different context.
protocol EncodingStorage {
    var header: Header { get }
    var payloadSize: Int { get }
    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>)

    mutating func optimize(for context: OptimizationContext)
}

extension EncodingStorage {
    var size: Int { header.size + payloadSize }
    func write(to data: Slice<UnsafeMutableRawBufferPointer>) {
        assert(data.count >= size)

        var data = data
        header.write(to: &data)
        writePayload(to: data)
    }
}
