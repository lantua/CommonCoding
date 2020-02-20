//
//  UnkeyedEncoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation

class UnkeyedEncodingStorage: TemporaryEncodingStorage {
    var values: [TemporaryEncodingStorage] = []

    func finalize() -> EncodingStorage {
        UnkeyedOptimizableStorage(values: values.map { $0.finalize() })
    }
}

struct UnkeyedBinaryEncodingContainer: UnkeyedEncodingContainer {
    let storage: UnkeyedEncodingStorage, context: EncodingContext

    var codingPath: [CodingKey] { context.codingPath }
    var count: Int { storage.values.count }

    @discardableResult
    private mutating func register<T>(_ value: T) -> T where T: TemporaryEncodingStorage {
        storage.values.append(value)
        return value
    }

    mutating func encodeNil() throws { storage.values.append(NilOptimizableStorage()) }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        try value.encode(to: InternalEncoder(storage: register(.init()), context: context.appending(UnkeyedCodingKey(intValue: count))))
    }

    mutating func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        .init(KeyedBinaryEncodingContainer<NestedKey>(storage: register(.init()), context: context.appending(UnkeyedCodingKey(intValue: count))))
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        UnkeyedBinaryEncodingContainer(storage: register(.init()), context: context.appending(UnkeyedCodingKey(intValue: count)))
    }

    mutating func superEncoder() -> Encoder {
        InternalEncoder(storage: register(.init()), context: context.appending(UnkeyedCodingKey(intValue: count)))
    }
}
