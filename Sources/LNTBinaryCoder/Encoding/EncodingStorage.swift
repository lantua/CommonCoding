//
//  EncodingStorage.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation

protocol TemporaryEncodingStorage {
    func finalize() -> EncodingStorage
}

protocol EncodingStorage: TemporaryEncodingStorage {
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

    func finalize() -> EncodingStorage { self }
}
