//
//  InternalEncoder.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation
import LNTSharedCoding

// MARK: Context

/// Encoding context, shared between all internal encoders, containers, etc. during encoding process.
struct EncodingContext {
    fileprivate class Shared {
        let userInfo: [CodingUserInfoKey: Any]
        var strings: [String: Int] = [:]

        init(userInfo: [CodingUserInfoKey: Any]) {
            self.userInfo = userInfo
        }
    }

    fileprivate let shared: Shared
    var path: CodingPath = .root

    var userInfo: [CodingUserInfoKey: Any] { shared.userInfo }
    var codingPath: [CodingKey] { path.codingPath }

    init(userInfo: [CodingUserInfoKey: Any]) {
        shared = .init(userInfo: userInfo)
    }

    func register(string: String) {
        shared.strings[string, default: 0] += 1
    }

    func optimize() -> [String] {
        shared.strings.sorted { $0.1 > $1.1 }.map { $0.key }
    }
}

extension EncodingContext {
    func appending(_ key: CodingKey) -> EncodingContext {
        var temp = self
        temp.path = .child(key: key, parent: path)
        return temp
    }
}

// MARK: Encoder

struct InternalEncoder: Encoder {
    let parent: TemporaryEncodingStorage, context: EncodingContext

    var userInfo: [CodingUserInfoKey : Any] { context.userInfo }
    var codingPath: [CodingKey] { context.codingPath }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        .init(KeyedBinaryEncodingContainer(parent: parent, context: context))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        UnkeyedBinaryEncodingContainer(parent: parent, context: context)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        self
    }
}

// MARK: Keyed Container

struct KeyedBinaryEncodingContainer<Key>: KeyedEncodingContainerProtocol where Key: CodingKey {
    private let storage: Storage, context: EncodingContext

    var codingPath: [CodingKey] { context.codingPath }

    init(parent: TemporaryEncodingStorage, context: EncodingContext) {
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

extension KeyedBinaryEncodingContainer {
    private class Storage {
        let parent: TemporaryEncodingStorage
        private var values: [String: EncodingOptimizer] = [:]

        init(parent: TemporaryEncodingStorage) {
            self.parent = parent
        }

        func temporaryWriter(for key: String) -> Writer {
            values[key] = NilOptimizer()
            return .init(parent: self, key: key)
        }

        struct Writer: TemporaryEncodingStorage {
            let parent: Storage, key: String

            func register(_ newValue: EncodingOptimizer) {
                parent.values[key] = newValue
            }
        }

        deinit { parent.register(KeyedOptimizer(values: values)) }
    }
}

// MARK: Unkeyed Container

struct UnkeyedBinaryEncodingContainer: UnkeyedEncodingContainer {
    private let storage: Storage, context: EncodingContext

    var codingPath: [CodingKey] { context.codingPath }
    var count: Int { storage.count }

    init(parent: TemporaryEncodingStorage, context: EncodingContext) {
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

extension UnkeyedBinaryEncodingContainer {
    private class Storage {
        private let parent: TemporaryEncodingStorage
        private var values: [EncodingOptimizer] = []

        var count: Int { values.count }

        init(parent: TemporaryEncodingStorage) {
            self.parent = parent
        }

        func temporaryWriter() -> Writer {
            defer { values.append(NilOptimizer()) }
            return .init(parent: self, index: values.count)
        }

        struct Writer: TemporaryEncodingStorage {
            let parent: Storage, index: Int

            func register(_ newValue: EncodingOptimizer) {
                parent.values[index] = newValue
            }
        }

        deinit { parent.register(UnkeyedOptimizer(values: values)) }
    }
}

// MARK: Single Value Container

extension InternalEncoder: SingleValueEncodingContainer {
    func encodeNil() throws { parent.register(NilOptimizer()) }

    func encode(_ value: String) throws {
        context.register(string: value)
        parent.register(StringStorage(string: value))
    }

    func encode(_ value: Bool) throws { try encode(value ? 1 : 0 as UInt8) }
    func encode(_ value: Double) throws { try encode(value.bitPattern) }
    func encode(_ value: Float) throws { try encode(value.bitPattern) }

    func encode<T>(_ value: T) throws where T: Encodable, T: FixedWidthInteger, T: SignedInteger {
        parent.register(SignedOptimizer(value: value))
    }
    func encode<T>(_ value: T) throws where T: Encodable, T: FixedWidthInteger, T: UnsignedInteger {
        parent.register(UnsignedOptimizer(value: value))
    }

    func encode<T>(_ value: T) throws where T : Encodable {
        try value.encode(to: self)
    }
}
