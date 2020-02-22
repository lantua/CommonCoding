//
//  Decoder.swift
//  LNTCSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

/// Decoding context, shared between all internal decoders, containers, etc. during single-element decoding process.
struct DecodingContext {
    private let decoder: CSVDecoder
    /// Field values, sorted by column.
    private let values: [String?]

    var userInfo: [CodingUserInfoKey: Any] { return decoder.userInfo }

    init(decoder: CSVDecoder, values: [String?]) {
        self.decoder = decoder
        self.values = values
    }

    /// Returns value at given (schema, coding path), converted to type `T`.
    func value<T>(at scope: (Schema, [CodingKey])) throws -> T where T: LosslessStringConvertible {
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

    func hasValue(at schema: Schema) -> Bool {
        return schema.contains { values[$0] != nil }
    }
}

/// Internal decoder. This is what the `Decodable` uses when decoding
struct CSVInternalDecoder: Decoder {
    let context: DecodingContext, schema: Schema, codingPath: [CodingKey]

    var userInfo: [CodingUserInfoKey: Any] { return context.userInfo }
    var scope: (Schema, [CodingKey]) { return (schema, codingPath) }
    
    init(context: DecodingContext, scope: (Schema, [CodingKey])) {
        self.context = context
        (schema, codingPath) = scope
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        return try .init(CSVKeyedDecodingContainer(decoder: self))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(decoder: self)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }
}

private struct CSVKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: CSVInternalDecoder, schemas: [String: Schema]

    var context: DecodingContext { return decoder.context }
    var codingPath: [CodingKey] { return decoder.codingPath }

    var allKeys: [Key] {
        // Includes only keys with non-nil value.
        //
        // Decodables that uses this is usually dynamic, so `nil` fields would be used
        // to mark the absence of key. If the key definitely must be present, it's usually
        // hard-coded in the generated/user-defined `init(from:)` and bypass this value anyway.
        return schemas.filter { context.hasValue(at: $0.value) }.map { Key(stringValue: $0.key)! }
    }

    init(decoder: CSVInternalDecoder) throws {
        guard let schemas = decoder.schema.getContainer(keyedBy: Key.self) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Expecting multi-field object"))
        }
        self.decoder = decoder
        self.schemas = schemas
    }

    private func schema(forKey key: CodingKey) throws -> Schema {
        guard let schema = schemas[key.stringValue] else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
        }
        return schema
    }

    private func scope(forKey key: CodingKey) throws -> (Schema, [CodingKey]) {
        return try (schema(forKey: key), codingPath + [key])
    }

    private func decoder(forKey key: CodingKey) throws -> CSVInternalDecoder {
        return try .init(context: context, scope: scope(forKey: key))
    }
    
    func contains(_ key: Key) -> Bool { return schemas[key.stringValue] != nil }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        return try !context.hasValue(at: schema(forKey: key))
    }

    func decode<T>(_: T.Type, forKey key: Key) throws -> T where T: Decodable, T: LosslessStringConvertible {
        return try context.value(at: scope(forKey: key))
    }

    func decode<T>(_: T.Type, forKey key: Key) throws -> T where T: Decodable {
        return try .init(from: decoder(forKey: key))
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        return try .init(CSVKeyedDecodingContainer<NestedKey>(decoder: decoder(forKey: key)))
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(decoder: decoder(forKey: key))
    }

    func superDecoder() throws -> Decoder { return try decoder(forKey: SuperCodingKey()) }
    func superDecoder(forKey key: Key) throws -> Decoder { return try decoder(forKey: key) }
}

private struct CSVUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let decoder: CSVInternalDecoder

    var context: DecodingContext { return decoder.context }
    var codingPath: [CodingKey] { return decoder.codingPath }
    let schemas: [Schema]
    
    let count: Int?
    var currentIndex = 0
    var isAtEnd: Bool { return currentIndex == count }

    init(decoder: CSVInternalDecoder) throws {
        guard let schemas = decoder.schema.getUnkeyedContainer() else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Expecting multi-field object"))
        }
        self.decoder = decoder
        self.schemas = schemas
        self.count = 1 + (schemas.lastIndex(where: decoder.context.hasValue) ?? -1)
    }

    private mutating func consumeScope() throws -> (Schema, [CodingKey]) {
        defer { currentIndex += 1 }
        guard schemas.indices ~= currentIndex else {
            throw DecodingError.keyNotFound(UnkeyedCodingKey(intValue: currentIndex), .init(codingPath: codingPath, debugDescription: ""))
        }
        return (schemas[currentIndex], codingPath + [UnkeyedCodingKey(intValue: currentIndex)])
    }

    private mutating func consumeDecoder() throws -> CSVInternalDecoder {
        return try .init(context: context, scope: consumeScope())
    }

    mutating func decodeNil() throws -> Bool {
        let hasValue = try context.hasValue(at: consumeScope().0)
        if hasValue {
            currentIndex -= 1
        }
        return !hasValue
    }
    
    mutating func decode<T>(_: T.Type) throws -> T where T: Decodable, T: LosslessStringConvertible {
        return try context.value(at: consumeScope())
    }
    
    mutating func decode<T>(_: T.Type) throws -> T where T: Decodable {
        return try .init(from: consumeDecoder())
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        return try .init(CSVKeyedDecodingContainer(decoder: consumeDecoder()))
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(decoder: consumeDecoder())
    }

    mutating func superDecoder() throws -> Decoder { return try consumeDecoder() }
}

extension CSVInternalDecoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool { return !context.hasValue(at: schema) }

    func decode<T>(_: T.Type) throws -> T where T: Decodable, T: LosslessStringConvertible {
        return try context.value(at: scope)
    }

    func decode<T>(_: T.Type) throws -> T where T: Decodable {
        return try .init(from: self)
    }
}
