//
//  Decoder.swift
//  CSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

import LNTCommonCoder

struct DecodingContext {
    private let decoder: CSVDecoder
    var userInfo: [CodingUserInfoKey: Any] { return decoder.userInfo }
    
    private let values: [String?]

    init(decoder: CSVDecoder, values: [String?]) {
        self.decoder = decoder
        self.values = values
    }
    
    func value<T>(at scope: (CSVSchema, [CodingKey])) throws -> T where T: LosslessStringConvertible {
        guard let index = scope.0.getValue() else {
            throw DecodingError.typeMismatch(T.self, .init(codingPath: scope.1, debugDescription: "Multi-field object found"))
        }
        guard let string = values[index] else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: scope.1, debugDescription: ""))
        }
        guard let result = T(string) else {
            throw DecodingError.typeMismatch(T.self, .init(codingPath: scope.1, debugDescription: "Trying to decode `\(string)`"))
        }

        return result
    }

    func hasValue(at schema: CSVSchema) -> Bool {
        return schema.contains { values.indices ~= $0 && values[$0] != nil }
    }
}

struct CSVInternalDecoder: Decoder {
    let context: DecodingContext, schema: CSVSchema, codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { return context.userInfo }
    
    init(context: DecodingContext, scope: (CSVSchema, [CodingKey])) {
        self.context = context
        (self.schema, self.codingPath) = scope
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        return try KeyedDecodingContainer(CSVKeyedDecodingContainer(context: context, scope: (schema, codingPath)))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(context: context, scope: (schema, codingPath))
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return CSVSingleValueDecodingContainer(context: context, scope: (schema, codingPath))
    }
}

private struct CSVKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let context: DecodingContext, schemas: [String: CSVSchema], codingPath: [CodingKey]
    var allKeys: [Key] {
        // Includes only keys with non-nil value.
        //
        // Decodables that uses this is usually dynamic, so `nil` fields would be used
        // to mark the absence of key. If the key definitely must be present, it's usually
        // hard-coded in the generated/user-defined `init(from:)` and bypass this value anyway.
        return schemas.compactMap { context.hasValue(at: $0.value) ? Key(stringValue: $0.key) : nil }
    }
    
    init(context: DecodingContext, scope: (CSVSchema, [CodingKey])) throws {
        guard let schemas = scope.0.getContainer(keyedBy: Key.self) else {
            throw DecodingError.dataCorrupted(.init(codingPath: scope.1, debugDescription: "Only keyed/unkeyed schemas are supported by CSVKeyedDecodingContainer"))
        }
        self.schemas = schemas
        self.context = context
        self.codingPath = scope.1
    }

    private func scope(for key: CodingKey) throws -> (CSVSchema, [CodingKey]) {
        guard let schema = schemas[key.stringValue] else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
        }
        return (schema, codingPath + [key])
    }
    
    func contains(_ key: Key) -> Bool { return schemas[key.stringValue] != nil }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        return try !context.hasValue(at: scope(for: key).0)
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable, T: LosslessStringConvertible {
        return try context.value(at: scope(for: key))
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        return try .init(from: CSVInternalDecoder(context: context, scope: scope(for: key)))
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        return try .init(CSVKeyedDecodingContainer<NestedKey>(context: context, scope: scope(for: key)))
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(context: context, scope: scope(for: key))
    }
    
    func superDecoder() throws -> Decoder {
        return try CSVInternalDecoder(context: context, scope: scope(for: SuperCodingKey()))
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        return try CSVInternalDecoder(context: context, scope: scope(for: key))
    }
}

private struct CSVUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let context: DecodingContext, schemas: [CSVSchema], codingPath: [CodingKey]
    
    let count: Int?
    var currentIndex = 0
    var isAtEnd: Bool { return currentIndex == count }

    init(context: DecodingContext, scope: (CSVSchema, [CodingKey])) throws {
        guard let schemas = scope.0.getUnkeyedContainer() else {
            throw DecodingError.dataCorrupted(.init(codingPath: scope.1, debugDescription: "Only keyed/unkeyed schemas are supported by CSVUnkeyedDecodingContainer"))
        }
        self.schemas = schemas
        self.count = 1 + (schemas.lastIndex(where: context.hasValue(at:)) ?? -1)
        self.context = context
        self.codingPath = scope.1
    }

    private mutating func consumeScope() -> (CSVSchema, [CodingKey]) {
        // We could check against `count` bound, but that would make it impossible to decode `Optional` past
        // the last non-nil value. That's probably not what we want
        defer { currentIndex += 1 }
        guard schemas.indices ~= currentIndex else {
            return (.init(), codingPath + [UnkeyedCodingKey(intValue: currentIndex)])
        }
        return (schemas[currentIndex], codingPath + [UnkeyedCodingKey(intValue: currentIndex)])
    }

    mutating func decodeNil() throws -> Bool {
        let hasValue = context.hasValue(at: consumeScope().0)
        if hasValue {
            currentIndex -= 1
        }
        return !hasValue
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable, T: LosslessStringConvertible {
        return try context.value(at: consumeScope())
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        return try .init(from: CSVInternalDecoder(context: context, scope: consumeScope()))
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        return try .init(CSVKeyedDecodingContainer(context: context, scope: consumeScope()))
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(context: context, scope: consumeScope())
    }
    
    mutating func superDecoder() throws -> Decoder {
        return CSVInternalDecoder(context: context, scope: consumeScope())
    }
}

private struct CSVSingleValueDecodingContainer: SingleValueDecodingContainer {
    let context: DecodingContext, schema: CSVSchema, codingPath: [CodingKey]

    init(context: DecodingContext, scope: (CSVSchema, [CodingKey])) {
        self.context = context
        (self.schema, self.codingPath) = scope
    }
    
    func decodeNil() -> Bool { return !context.hasValue(at: schema) }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable, T: LosslessStringConvertible {
        return try context.value(at: (schema, codingPath))
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        return try .init(from: CSVInternalDecoder(context: context, scope: (schema, codingPath)))
    }
}
