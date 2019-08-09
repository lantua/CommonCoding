//
//  Decoder.swift
//  LNTCSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

struct DecodingContext {
    private let decoder: CSVDecoder
    private let values: [String?]

    var userInfo: [CodingUserInfoKey: Any] { return decoder.userInfo }

    init(decoder: CSVDecoder, values: [String?]) {
        self.decoder = decoder
        self.values = values
    }
    
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

struct CSVInternalDecoder: Decoder {
    let context: DecodingContext, schema: Schema, codingPath: [CodingKey]

    var userInfo: [CodingUserInfoKey: Any] { return context.userInfo }
    var scope: (Schema, [CodingKey]) { return (schema, codingPath) }
    
    init(context: DecodingContext, scope: (Schema, [CodingKey])) {
        self.context = context
        (schema, codingPath) = scope
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        return try KeyedDecodingContainer(CSVKeyedDecodingContainer(context: context, scope: scope))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(context: context, scope: scope)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return CSVSingleValueDecodingContainer(context: context, scope: scope)
    }
}

private struct CSVKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let context: DecodingContext, schemas: [String: Schema], codingPath: [CodingKey]

    var allKeys: [Key] {
        // Includes only keys with non-nil value.
        //
        // Decodables that uses this is usually dynamic, so `nil` fields would be used
        // to mark the absence of key. If the key definitely must be present, it's usually
        // hard-coded in the generated/user-defined `init(from:)` and bypass this value anyway.
        return schemas.filter { context.hasValue(at: $0.value) }.map { Key(stringValue: $0.key)! }
    }
    
    init(context: DecodingContext, scope: (Schema, [CodingKey])) throws {
        guard let schemas = scope.0.getContainer(keyedBy: Key.self) else {
            throw DecodingError.dataCorrupted(.init(codingPath: scope.1, debugDescription: "Expecting multi-field object"))
        }
        self.schemas = schemas
        self.context = context
        self.codingPath = scope.1
    }

    private func scope(forKey key: CodingKey) throws -> (Schema, [CodingKey]) {
        guard let schema = schemas[key.stringValue] else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
        }
        return (schema, codingPath + [key])
    }

    private func decoder(forKey key: CodingKey) throws -> Decoder {
        return try CSVInternalDecoder(context: context, scope: scope(forKey: key))
    }
    
    func contains(_ key: Key) -> Bool { return schemas[key.stringValue] != nil }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        return try !context.hasValue(at: scope(forKey: key).0)
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable, T: LosslessStringConvertible {
        return try context.value(at: scope(forKey: key))
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable { return try .init(from: decoder(forKey: key)) }
    func superDecoder() throws -> Decoder { return try decoder(forKey: SuperCodingKey()) }
    func superDecoder(forKey key: Key) throws -> Decoder { return try decoder(forKey: key) }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        return try .init(CSVKeyedDecodingContainer<NestedKey>(context: context, scope: scope(forKey: key)))
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(context: context, scope: scope(forKey: key))
    }
}

private struct CSVUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let context: DecodingContext, schemas: [Schema], codingPath: [CodingKey]
    
    let count: Int?
    var currentIndex = 0
    var isAtEnd: Bool { return currentIndex == count }

    init(context: DecodingContext, scope: (Schema, [CodingKey])) throws {
        guard let schemas = scope.0.getUnkeyedContainer() else {
            throw DecodingError.dataCorrupted(.init(codingPath: scope.1, debugDescription: "Expecting multi-field object"))
        }
        self.schemas = schemas
        self.count = 1 + (schemas.lastIndex(where: context.hasValue) ?? -1)
        self.context = context
        self.codingPath = scope.1
    }

    private mutating func consumeScope() throws -> (Schema, [CodingKey]) {
        defer { currentIndex += 1 }
        guard schemas.indices ~= currentIndex else {
            throw DecodingError.keyNotFound(UnkeyedCodingKey(intValue: currentIndex), .init(codingPath: codingPath, debugDescription: ""))
        }
        return (schemas[currentIndex], codingPath + [UnkeyedCodingKey(intValue: currentIndex)])
    }

    private mutating func consumeDecoder() throws -> Decoder {
        return try CSVInternalDecoder(context: context, scope: consumeScope())
    }

    mutating func decodeNil() throws -> Bool {
        let hasValue = try context.hasValue(at: consumeScope().0)
        if hasValue {
            currentIndex -= 1
        }
        return !hasValue
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable, T: LosslessStringConvertible {
        return try context.value(at: consumeScope())
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable { return try .init(from: consumeDecoder()) }
    mutating func superDecoder() throws -> Decoder { return try consumeDecoder() }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        return try .init(CSVKeyedDecodingContainer(context: context, scope: consumeScope()))
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(context: context, scope: consumeScope())
    }
}

private struct CSVSingleValueDecodingContainer: SingleValueDecodingContainer {
    let context: DecodingContext, schema: Schema, codingPath: [CodingKey]

    var scope: (Schema, [CodingKey]) { return (schema, codingPath) }

    init(context: DecodingContext, scope: (Schema, [CodingKey])) {
        self.context = context
        (schema, codingPath) = scope
    }
    
    func decodeNil() -> Bool { return !context.hasValue(at: schema) }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable, T: LosslessStringConvertible {
        return try context.value(at: scope)
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        return try .init(from: CSVInternalDecoder(context: context, scope: scope))
    }
}
