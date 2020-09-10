//
//  Decoder.swift
//  LNTCSVCoding
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

import LNTSharedCoding

// MARK: Context

struct SharedDecodingContext {
    let values: [String?]
}
extension CodingContext where Shared == SharedDecodingContext {
    func value<T>(at schema: Schema) throws -> T where T: LosslessStringConvertible {
        guard let index = schema.getValue() else {
            throw DecodingError.typeMismatch(T.self, error("Multi-field object found"))
        }
        guard let string = shared.values[index] else {
            throw DecodingError.valueNotFound(String.self, error())
        }
        guard let result = T(string) else {
            throw DecodingError.typeMismatch(T.self, error("Trying to decode `\(string)`"))
        }

        return result
    }

    func hasValue(at schema: Schema) -> Bool {
        schema.contains { shared.values[$0] != nil }
    }
}

// MARK: Decoder

/// Internal decoder. This is what the `Decodable` uses when decoding
struct CSVInternalDecoder: ContextContainer, Decoder {
    let context: CodingContext<SharedDecodingContext>, schema: Schema

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        try .init(CSVKeyedDecodingContainer(decoder: self))
    }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer { try CSVUnkeyedDecodingContainer(decoder: self) }
    func singleValueContainer() throws -> SingleValueDecodingContainer { self }
}

extension CSVInternalDecoder {
    init(decoder: CSVDecoder, values: [String?], schema: Schema) {
        context = .init(.init(values: values), userInfo: decoder.userInfo)
        self.schema = schema
    }
}

// MARK: Keyed Container

private struct CSVKeyedDecodingContainer<Key: CodingKey>: ContextContainer, KeyedDecodingContainerProtocol {
    let context: CodingContext<SharedDecodingContext>, schemas: [String: Schema]

    var allKeys: [Key] {
        // Includes only keys with non-nil value.
        //
        // Decodables that uses this is usually dynamic, so `nil` fields would be used
        // to mark the absence of key. If the key definitely must be present, it's usually
        // hard-coded in the generated/user-defined `init(from:)` and bypass this value anyway.
        schemas.filter { context.hasValue(at: $0.value) }.compactMap { Key(stringValue: $0.key) }
    }

    init(decoder: CSVInternalDecoder) throws {
        self.context = decoder.context

        guard let schemas = decoder.schema.getKeyedContainer() else {
            throw DecodingError.dataCorrupted(context.error("Expecting multi-field object"))
        }
        self.schemas = schemas
    }

    private func schema(forKey key: CodingKey) throws -> Schema {
        guard let schema = schemas[key.stringValue] else {
            throw DecodingError.keyNotFound(key, context.error())
        }
        return schema
    }
    private func decoder(forKey key: CodingKey) throws -> CSVInternalDecoder {
        try .init(context: context.appending(key), schema: schema(forKey: key))
    }
    
    func contains(_ key: Key) -> Bool { schemas[key.stringValue] != nil }

    func decodeNil(forKey key: Key) throws -> Bool { try !context.hasValue(at: schema(forKey: key)) }

    func decode<T>(_: T.Type, forKey key: Key) throws -> T where T: Decodable, T: LosslessStringConvertible {
        try context.value(at: schema(forKey: key))
    }

    func decode<T>(_: T.Type, forKey key: Key) throws -> T where T: Decodable { try .init(from: decoder(forKey: key)) }
    func superDecoder() throws -> Decoder { try decoder(forKey: SuperCodingKey()) }
    func superDecoder(forKey key: Key) throws -> Decoder { try decoder(forKey: key) }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer { try decoder(forKey: key).unkeyedContainer() }
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        try decoder(forKey: key).container(keyedBy: NestedKey.self)
    }
}

// MARK: Unkeyed Container

private struct CSVUnkeyedDecodingContainer: ContextContainer, UnkeyedDecodingContainer {
    let context: CodingContext<SharedDecodingContext>, schemas: [Schema]
    
    let count: Int?
    var currentIndex = 0
    var isAtEnd: Bool { currentIndex == count }

    init(decoder: CSVInternalDecoder) throws {
        self.context = decoder.context

        guard let schemas = decoder.schema.getUnkeyedContainer() else {
            throw DecodingError.dataCorrupted(context.error("Expecting multi-field object"))
        }
        self.schemas = schemas
        self.count = 1 + (schemas.lastIndex(where: decoder.context.hasValue) ?? -1)
    }

    private mutating func consumeSchema() throws -> Schema {
        defer { currentIndex += 1 }
        guard schemas.indices ~= currentIndex else {
            throw DecodingError.keyNotFound(UnkeyedCodingKey(intValue: currentIndex), context.error())
        }
        return schemas[currentIndex]
    }

    private mutating func consumeDecoder() throws -> CSVInternalDecoder {
        try .init(context: context, schema: consumeSchema())
    }

    mutating func decodeNil() throws -> Bool {
        let hasValue = try context.hasValue(at: consumeSchema())
        if hasValue {
            currentIndex -= 1
        }
        return !hasValue
    }
    
    mutating func decode<T>(_: T.Type) throws -> T where T: Decodable, T: LosslessStringConvertible {
        try context.appending(UnkeyedCodingKey(intValue: currentIndex)).value(at: consumeSchema())
    }
    
    mutating func decode<T>(_: T.Type) throws -> T where T: Decodable { try .init(from: consumeDecoder()) }
    mutating func superDecoder() throws -> Decoder { try consumeDecoder() }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer { try consumeDecoder().unkeyedContainer() }
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        try .init(CSVKeyedDecodingContainer(decoder: consumeDecoder()))
    }
}

// MARK: Single Value Container

extension CSVInternalDecoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool { !context.hasValue(at: schema) }

    func decode<T>(_: T.Type) throws -> T where T: Decodable { try .init(from: self) }
    func decode<T>(_: T.Type) throws -> T where T: Decodable, T: LosslessStringConvertible { try context.value(at: schema) }
}
