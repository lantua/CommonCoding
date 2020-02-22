//
//  SingleEncoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 16/2/2563 BE.
//

import Foundation

class TempSingleValueStorage: TemporaryEncodingStorage {
    var value: TemporaryEncodingStorage = NilStorage()

    func finalize() -> EncodingStorage {
        value.finalize()
    }
}

struct SingleValueBinaryEncodingContainer: SingleValueEncodingContainer {
    let storage: TempSingleValueStorage, context: EncodingContext

    var codingPath: [CodingKey] { context.codingPath }

    mutating func encodeNil() throws {
        storage.value = NilStorage()
    }

    mutating func encode(_ value: String) throws {
        context.register(string: value)
        storage.value = StringStorage(string: value)
    }

    mutating func encode(_ value: Bool) throws { try encode(value ? 1 : 0 as UInt8) }
    mutating func encode(_ value: Double) throws { try encode(value.bitPattern) }
    mutating func encode(_ value: Float) throws { try encode(value.bitPattern) }

    mutating func encode<T>(_ value: T) throws where T: Encodable, T: FixedWidthInteger, T: SignedInteger {
        storage.value = SignedStorage(value: value)
    }
    mutating func encode<T>(_ value: T) throws where T: Encodable, T: FixedWidthInteger, T: UnsignedInteger {
        storage.value = UnsignedStorage(value: value)
    }
    
    mutating func encode<T>(_ value: T) throws where T : Encodable {
        try value.encode(to: InternalEncoder(storage: storage, context: context))
    }
}
