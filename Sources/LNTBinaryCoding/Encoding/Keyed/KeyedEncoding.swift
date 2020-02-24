//
//  KeyedEncoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation
import LNTSharedCoding

struct KeyedBinaryEncodingContainer<Key>: KeyedEncodingContainerProtocol where Key: CodingKey {
    private let storage: KeyedTemporaryEncodingStorage, context: EncodingContext

    var codingPath: [CodingKey] { context.codingPath }

    init(parent: TemporaryEncodingStorageWriter, context: EncodingContext) {
        storage = .init(parent: parent)
        self.context = context
    }

    private func encoder(for key: CodingKey) -> InternalEncoder {
        let keyString = key.stringValue
        context.register(string: keyString)
        return .init(parent: storage.temporaryWriter(for: keyString), context: context.appending(key))
    }

    func encodeNil(forKey key: Key) throws {
        var container = encoder(for: key).singleValueContainer()
        try container.encodeNil()
    }

    func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable { try value.encode(to: encoder(for: key)) }
    func superEncoder() -> Encoder { encoder(for: SuperCodingKey()) }
    func superEncoder(forKey key: Key) -> Encoder { encoder(for: key) }
    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer { encoder(for: key).unkeyedContainer() }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        encoder(for: key).container(keyedBy: NestedKey.self)
    }
}

private class KeyedTemporaryEncodingStorage {
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
