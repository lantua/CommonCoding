//
//  InternalDecoder.swift
//  LNTBinaryCoding
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

import Foundation
import LNTSharedCoding

typealias HeaderData = (header: Header, data: Data)

// MARK: Context

struct DecodingContext {
    private let strings: [String], path: CodingPath

    let userInfo: [CodingUserInfoKey: Any]
    var codingPath: [CodingKey] { path.codingPath }
}

extension DecodingContext {
    init(userInfo: [CodingUserInfoKey: Any], data: inout Data) throws {
        guard data.count >= 2 else {
            throw BinaryDecodingError.emptyFile
        }

        guard data.removeFirst() == 0x00,
            data.removeFirst() == 0x00 else {
                throw BinaryDecodingError.invalidFileVersion
        }

        let count = try data.extractVSUI()

        self.userInfo = userInfo
        self.path = .root
        self.strings = try (0..<count).map { _ in
            try data.readString()
        }
    }
}

extension DecodingContext {
    /// Returns new context with coding path being appended by `key`.
    func appending(_ key: CodingKey) -> DecodingContext {
        .init(strings: strings, path: .child(key: key, parent: path), userInfo: userInfo)
    }

    func string(at index: Int) throws -> String {
        let index = index - 1
        guard strings.indices ~= index else {
            throw BinaryDecodingError.invalidStringMapIndex
        }
        return strings[index]
    }
}

// MARK: Encoder

struct InternalDecoder: Decoder {
    let storage: PartiallyParsedStorage, context: DecodingContext

    init(_ arg: HeaderData, context: DecodingContext) throws {
        do {
            self.storage = try .init(arg, context: context)
        } catch {
            throw DecodingError.dataCorrupted(context.error(error: error))
        }
        self.context = context
    }

    var userInfo: [CodingUserInfoKey : Any] { context.userInfo }
    var codingPath: [CodingKey] { context.codingPath }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        guard case let .keyed(values) = storage else {
            throw DecodingError.typeMismatch(KeyedDecodingContainer<Key>.self, context.error("Incompatible container found"))
        }

        return .init(KeyedBinaryDecodingContainer(values: values, context: context))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case let .unkeyed(values) = storage else {
            throw DecodingError.typeMismatch(UnkeyedDecodingContainer.self, context.error("Incompatible container found"))
        }

        return UnkeyedBinaryDecodingContainer(values: values, context: context)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer { self }
}

// MARK: Keyed Container

struct KeyedBinaryDecodingContainer<Key>: KeyedDecodingContainerProtocol where Key: CodingKey {
    let values: [String: HeaderData], context: DecodingContext

    var codingPath: [CodingKey] { context.codingPath }
    var allKeys: [Key] { values.keys.compactMap(Key.init(stringValue:)) }
    func contains(_ key: Key) -> Bool { values.keys.contains(key.stringValue) }

    private func decoder(for key: CodingKey) throws -> InternalDecoder {
        guard let value = values[key.stringValue] else {
            throw DecodingError.keyNotFound(key, context.error())
        }

        return try .init(value, context: context.appending(key))
    }

    func decodeNil(forKey key: Key) throws -> Bool { values[key.stringValue]?.header.isNil ?? true }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable { try T(from: decoder(for: key)) }
    func superDecoder() throws -> Decoder { try decoder(for: SuperCodingKey()) }
    func superDecoder(forKey key: Key) throws -> Decoder { try decoder(for: key) }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer { try decoder(for: key).unkeyedContainer() }
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try decoder(for: key).container(keyedBy: NestedKey.self)
    }
}

// MARK: Unkeyed Container

struct UnkeyedBinaryDecodingContainer: UnkeyedDecodingContainer {
    private var values: ArraySlice<HeaderData>
    let context: DecodingContext

    let count: Int?
    var currentIndex = 0

    init(values: [HeaderData], context: DecodingContext) {
        self.values = values[...]
        self.context = context
        self.count = values.count
    }

    var codingPath: [CodingKey] { context.codingPath }
    var isAtEnd: Bool { values.isEmpty }

    mutating func consumeDecoder() throws -> InternalDecoder {
        guard !isAtEnd else {
            throw DecodingError.keyNotFound(UnkeyedCodingKey(intValue: currentIndex), context.error("End of container reached"))
        }

        defer { currentIndex += 1 }
        return try .init(values.removeFirst(), context: context.appending(UnkeyedCodingKey(intValue: currentIndex)))
    }

    mutating func decodeNil() throws -> Bool { values.first?.header.isNil ?? true }

    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable { try T(from: consumeDecoder()) }
    mutating func superDecoder() throws -> Decoder { try consumeDecoder() }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer { try consumeDecoder().unkeyedContainer() }
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try consumeDecoder().container(keyedBy: NestedKey.self)
    }
}

// MARK: Single Value Container

extension InternalDecoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool { storage.isNil }
    func decode(_: Bool.Type) throws -> Bool { try decode(UInt8.self) != 0 }
    func decode(_: Float.Type) throws -> Float { try Float(bitPattern: decode(UInt32.self)) }
    func decode(_: Double.Type) throws -> Double { try Double(bitPattern: decode(UInt64.self)) }

    func decode<T>(_: T.Type) throws -> T where T: Decodable, T: BinaryInteger {
        let tmp: T?
        switch storage {
        case let .signed(value): tmp = T(exactly: value)
        case let .unsigned(value): tmp = T(exactly: value)
        default: throw DecodingError.typeMismatch(T.self, context.error("Incompatible container"))
        }

        guard let result = tmp else {
            throw DecodingError.typeMismatch(T.self, context.error("Value out of range"))
        }

        return result
    }

    func decode(_: String.Type) throws -> String {
        guard case let .string(result) = storage else {
            throw DecodingError.typeMismatch(String.self, context.error("Incompatible container"))
        }

        return result
    }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable { try T(from: self) }
}
