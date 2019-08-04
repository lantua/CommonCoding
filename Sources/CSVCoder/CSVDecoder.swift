//
//  CSVDecoder.swift
//  CSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

public struct CSVDecodingOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Treat unescaped "" as non-nil empty string, also applied to header
    public static let treatEmptyStringAsValue = CSVDecodingOptions(rawValue: 1 << 0)
    /// Treat unescaped "null" as nil value, also applied to header
    public static let treatNullAsNil        = CSVDecodingOptions(rawValue: 1 << 1)
}

struct DecodingContext {
    private let decoder: CSVDecoder
    var userInfo: [CodingUserInfoKey: Any] { return decoder.userInfo }
    
    private let values: [String?]

    init(decoder: CSVDecoder, values: [String?]) {
        self.decoder = decoder
        self.values = values
    }
    
    func value<T>(at fieldIndex: Trie<Int>, codingPath: [CodingKey]) throws -> T where T: LosslessStringConvertible {
        guard let index = fieldIndex.value else {
            throw DecodingError.typeMismatch(T.self, .init(codingPath: codingPath, debugDescription: "Multi-field object found"))
        }
        guard let string = values[index] else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: codingPath, debugDescription: ""))
        }
        guard let result = T(string) else {
            throw DecodingError.typeMismatch(T.self, .init(codingPath: codingPath, debugDescription: "Trying to decode `\(string)`"))
        }

        return result
    }

    func isEmpty(at fieldIndex: Trie<Int>) -> Bool {
        return !fieldIndex.contains { values[$0] != nil }
    }
}

struct CSVInternalDecoder: Decoder {
    let context: DecodingContext, fieldIndices: Trie<Int>, codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { return context.userInfo }
    
    init(context: DecodingContext, fieldIndices: Trie<Int>, codingPath: [CodingKey]) {
        self.context = context
        self.fieldIndices = fieldIndices
        self.codingPath = codingPath
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        return KeyedDecodingContainer(CSVKeyedDecodingContainer(context: context, fieldIndices: fieldIndices, codingPath: codingPath))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return CSVUnkeyedDecodingContainer(context: context, fieldIndices: fieldIndices, codingPath: codingPath)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return CSVSingleValueDecodingContainer(context: context, fieldIndices: fieldIndices, codingPath: codingPath)
    }
}

private struct CSVKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let context: DecodingContext, fieldIndices: Trie<Int>, codingPath: [CodingKey]
    var allKeys: [Key] {
        return fieldIndices.children.compactMap {
            return context.isEmpty(at: $0.value) ? nil : Key(stringValue: $0.key)
        }
    }
    
    init(context: DecodingContext, fieldIndices: Trie<Int>, codingPath: [CodingKey]) {
        self.context = context
        self.fieldIndices = fieldIndices
        self.codingPath = codingPath
    }
    
    private func codingPath(for key: CodingKey) -> [CodingKey] {
        return codingPath + [key]
    }
    
    private func fieldIndices(for key: CodingKey) throws -> Trie<Int> {
        guard let fieldIndices = fieldIndices[key] else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
        }
        return fieldIndices
    }
    
    func contains(_ key: Key) -> Bool { return fieldIndices[key] != nil }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        return try context.isEmpty(at: fieldIndices(for: key))
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable, T: LosslessStringConvertible {
        return try context.value(at: fieldIndices(for: key), codingPath: codingPath(for: key))
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        return try .init(from: CSVInternalDecoder(context: context, fieldIndices: fieldIndices(for: key), codingPath: codingPath(for: key)))
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        return try .init(CSVKeyedDecodingContainer<NestedKey>(context: context, fieldIndices: fieldIndices(for: key), codingPath: codingPath(for: key)))
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(context: context, fieldIndices: fieldIndices(for: key), codingPath: codingPath(for: key))
    }
    
    func superDecoder() throws -> Decoder {
        return try CSVInternalDecoder(context: context, fieldIndices: fieldIndices(for: SuperCodingKey()), codingPath: codingPath(for: SuperCodingKey()))
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        return try CSVInternalDecoder(context: context, fieldIndices: fieldIndices(for: key), codingPath: codingPath(for: key))
    }
}

private struct CSVUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let context: DecodingContext, fieldIndices: Trie<Int>, codingPath: [CodingKey]
    
    let count: Int?
    var currentIndex = 0
    var isAtEnd: Bool { return currentIndex == count }

    init(context: DecodingContext, fieldIndices: Trie<Int>, codingPath: [CodingKey]) {
        self.context = context
        self.fieldIndices = fieldIndices
        self.codingPath = codingPath
        
        let candidates = fieldIndices.children.compactMap {
            return context.isEmpty(at: $0.value) ? nil : Int($0.key)
        }
        count = 1 + (candidates.max() ?? -1)
    }

    private var currentKey: CodingKey { return UnkeyedCodingKey(intValue: currentIndex) }
    private var currentCodingPath: [CodingKey] { return codingPath + [currentKey] }

    private mutating func consumeFieldIndices() throws -> Trie<Int> {
        guard currentIndex < count! else {
            throw DecodingError.keyNotFound(currentKey, .init(codingPath: codingPath, debugDescription: ""))
        }

        defer { currentIndex += 1 }
        return fieldIndices[currentKey] ?? Trie()
    }

    mutating func decodeNil() throws -> Bool {
        let isEmpty = try context.isEmpty(at: consumeFieldIndices())
        if !isEmpty {
            currentIndex -= 1
            assert(currentIndex >= 0)
        }
        return isEmpty
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable, T: LosslessStringConvertible {
        return try context.value(at: consumeFieldIndices(), codingPath: currentCodingPath)
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let currentFieldIndices = try consumeFieldIndices() // Must run before `currentCodingPath` is accessed below
        return try .init(from: CSVInternalDecoder(context: context, fieldIndices: currentFieldIndices, codingPath: currentCodingPath))
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let currentFieldIndices = try consumeFieldIndices() // Must run before `currentCodingPath` is accessed below
        return .init(CSVKeyedDecodingContainer(context: context, fieldIndices: currentFieldIndices, codingPath: currentCodingPath))
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let currentFieldIndices = try consumeFieldIndices() // Must run before `currentCodingPath` is accessed below
        return CSVUnkeyedDecodingContainer(context: context, fieldIndices: currentFieldIndices, codingPath: currentCodingPath)
    }
    
    mutating func superDecoder() throws -> Decoder {
        let currentFieldIndices = try consumeFieldIndices() // Must run before `currentCodingPath` is accessed below
        return CSVInternalDecoder(context: context, fieldIndices: currentFieldIndices, codingPath: currentCodingPath)
    }
}

private struct CSVSingleValueDecodingContainer: SingleValueDecodingContainer {
    let context: DecodingContext, fieldIndices: Trie<Int>, codingPath: [CodingKey]
    
    func decodeNil() -> Bool { return context.isEmpty(at: fieldIndices) }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable, T: LosslessStringConvertible {
        return try context.value(at: fieldIndices, codingPath: codingPath)
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        return try .init(from: CSVInternalDecoder(context: context, fieldIndices: fieldIndices, codingPath: codingPath))
    }
}
