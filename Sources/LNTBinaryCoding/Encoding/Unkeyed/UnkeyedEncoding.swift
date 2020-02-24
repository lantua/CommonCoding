//
//  UnkeyedEncoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation
import LNTSharedCoding

struct UnkeyedBinaryEncodingContainer: UnkeyedEncodingContainer {
    let storage: UnkeyedTemporaryEncodingStorage, context: EncodingContext

    var codingPath: [CodingKey] { context.codingPath }
    var count: Int { storage.count }

    init(parent: TemporaryEncodingStorageWriter, context: EncodingContext) {
        storage = .init(parent: parent)
        self.context = context
    }

    private func writer() -> TemporaryEncodingStorageWriter {
        storage.temporaryWriter()
    }

    mutating func encodeNil() throws { writer().register(NilStorage()) }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        try value.encode(to: InternalEncoder(context: context.appending(UnkeyedCodingKey(intValue: count)), parent: writer()))
    }

    mutating func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        .init(KeyedBinaryEncodingContainer<NestedKey>(parent: writer(), context: context.appending(UnkeyedCodingKey(intValue: count))))
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        UnkeyedBinaryEncodingContainer(parent: writer(), context: context.appending(UnkeyedCodingKey(intValue: count)))
    }

    mutating func superEncoder() -> Encoder {
        InternalEncoder(context: context.appending(UnkeyedCodingKey(intValue: count)), parent: writer())
    }
}

class UnkeyedTemporaryEncodingStorage {
    let parent: TemporaryEncodingStorageWriter
    private var values: [EncodingStorage] = []

    var count: Int { values.count }

    init(parent: TemporaryEncodingStorageWriter) {
        self.parent = parent
    }

    func temporaryWriter() -> UnkeyedTemporaryEncodingStorageWriter {
        values.append(NilStorage())
        return .init(parent: self, index: values.count - 1)
    }

    struct UnkeyedTemporaryEncodingStorageWriter: TemporaryEncodingStorageWriter {
        let parent: UnkeyedTemporaryEncodingStorage, index: Int

        func register(_ newValue: EncodingStorage) {
            parent.values[index] = newValue
        }
    }

    deinit { parent.register(UnkeyedStorage(values: values)) }
}
