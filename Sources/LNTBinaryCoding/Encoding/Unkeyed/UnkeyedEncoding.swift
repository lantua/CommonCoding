//
//  UnkeyedEncoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation
import LNTSharedCoding

struct UnkeyedBinaryEncodingContainer: UnkeyedEncodingContainer {
    private let storage: UnkeyedTemporaryEncodingStorage, context: EncodingContext

    var codingPath: [CodingKey] { context.codingPath }
    var count: Int { storage.count }

    init(parent: TemporaryEncodingStorageWriter, context: EncodingContext) {
        storage = .init(parent: parent)
        self.context = context
    }

    private func encoder() -> InternalEncoder {
        let encoderContext = context.appending(UnkeyedCodingKey(intValue: count))
        return .init(parent: storage.temporaryWriter(), context: encoderContext)
    }

    func encodeNil() throws {
        var container = encoder().singleValueContainer()
        try container.encodeNil()
    }

    func encode<T>(_ value: T) throws where T: Encodable { try value.encode(to: encoder()) }
    func superEncoder() -> Encoder { encoder() }
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer { encoder().unkeyedContainer() }
    func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        encoder().container(keyedBy: NestedKey.self)
    }
}

private class UnkeyedTemporaryEncodingStorage {
    private let parent: TemporaryEncodingStorageWriter
    private var values: [EncodingStorage] = []

    var count: Int { values.count }

    init(parent: TemporaryEncodingStorageWriter) {
        self.parent = parent
    }

    func temporaryWriter() -> UnkeyedTemporaryEncodingStorageWriter {
        defer { values.append(NilStorage()) }
        return .init(parent: self, index: values.count)
    }

    struct UnkeyedTemporaryEncodingStorageWriter: TemporaryEncodingStorageWriter {
        let parent: UnkeyedTemporaryEncodingStorage, index: Int

        func register(_ newValue: EncodingStorage) {
            parent.values[index] = newValue
        }
    }

    deinit { parent.register(UnkeyedStorage(values: values)) }
}
