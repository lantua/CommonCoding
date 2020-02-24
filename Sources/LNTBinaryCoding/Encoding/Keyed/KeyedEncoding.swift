//
//  KeyedEncoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation
import LNTSharedCoding

struct KeyedBinaryEncodingContainer<Key>: KeyedEncodingContainerProtocol where Key: CodingKey {
    let storage: KeyedTemporaryEncodingStorage, context: EncodingContext

    var codingPath: [CodingKey] { context.codingPath }

    init(parent: TemporaryEncodingStorageWriter, context: EncodingContext) {
        storage = .init(parent: parent)
        self.context = context
    }

    private func writer(key: CodingKey) -> TemporaryEncodingStorageWriter {
        let key = key.stringValue
        context.register(string: key)
        return storage.temporaryWriter(for: key)
    }

    mutating func encodeNil(forKey key: Key) throws {
        writer(key: key).register(NilStorage())
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        try value.encode(to: InternalEncoder(context: context.appending(key), parent: writer(key: key)))
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        .init(KeyedBinaryEncodingContainer<NestedKey>(parent: writer(key: key), context: context.appending(key)))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        UnkeyedBinaryEncodingContainer(parent: writer(key: key), context: context.appending(key))
    }

    mutating func superEncoder() -> Encoder {
        InternalEncoder(context: context.appending(SuperCodingKey()), parent: writer(key: SuperCodingKey()))
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        InternalEncoder(context: context.appending(key), parent: writer(key: key))
    }
}

class KeyedTemporaryEncodingStorage {
    let parent: TemporaryEncodingStorageWriter
    private var values: [String: EncodingStorage] = [:]

    init(parent: TemporaryEncodingStorageWriter) {
        self.parent = parent
    }

    func temporaryWriter(for key: String) -> KeyedTemporaryEncodingStorageWriter {
        values[key] = NilStorage()
        return .init(parent: self, key: key)
    }

    struct KeyedTemporaryEncodingStorageWriter: TemporaryEncodingStorageWriter {
        let parent: KeyedTemporaryEncodingStorage, key: String

        func register(_ newValue: EncodingStorage) {
            parent.values[key] = newValue
        }
    }

    deinit { parent.register(KeyedStorage(values: values)) }
}
