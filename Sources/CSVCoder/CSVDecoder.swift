//
//  CSVDecoder.swift
//  CSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

import Foundation

class DecodingContext {
    private let decoder: CSVDecoder
    
    var userInfo: [CodingUserInfoKey: Any] { return decoder.userInfo }
    
    private let data: [String]

    init(decoder: CSVDecoder, data: [String]) throws {
        self.decoder = decoder
        self.data = data
    }
    
    func value(at index: Int) -> String {
        return data[index]
    }
}

struct CSVInternalDecoder: Decoder {
    let context: DecodingContext, codingPath: [CodingKey], headers: Trie
    var userInfo: [CodingUserInfoKey: Any] { return context.userInfo }
    
    init(context: DecodingContext, headers: Trie, codingPath: [CodingKey]) {
        self.context = context
        self.headers = headers
        self.codingPath = codingPath
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        return KeyedDecodingContainer(CSVKeyedDecodingContainer(context: context, headers: headers, codingPath: codingPath))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(context: context, headers: headers, codingPath: codingPath)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return CSVSingleValueDecodingContainer(context: context, headers: headers, codingPath: codingPath)
    }
}

private struct CSVKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let context: DecodingContext, headers: Trie, codingPath: [CodingKey]
    let allKeys: [Key], allUniqueKeys: Set<String>
    
    init(context: DecodingContext, headers: Trie, codingPath: [CodingKey]) {
        self.context = context
        self.headers = headers
        self.codingPath = codingPath
    
        allKeys = headers.keys.compactMap { Key(stringValue: String($0)) }
        allUniqueKeys = Set(allKeys.map { $0.stringValue })
    }
    
    private func nextPath(for key: CodingKey) -> [CodingKey] {
        return codingPath + [key]
    }
    
    private func header(for key: CodingKey) throws -> Trie {
        guard let header = headers[key] else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Key not found"))
        }
        return header
    }
    
    func contains(_ key: Key) -> Bool { return allUniqueKeys.contains(key.stringValue) }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        let string = try decode(String.self, forKey: key)
        return string.isEmpty
    }
    
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        guard let index = headers[key]?.value else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Key not found"))
        }
        return context.value(at: index)
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable, T: LosslessStringConvertible {
        let string = try decode(String.self, forKey: key)
        guard let result = T(string) else {
            throw DecodingError.typeMismatch(T.self, .init(codingPath: nextPath(for: key), debugDescription: ""))
        }
        return result
    }
    
    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        let decoder = try CSVInternalDecoder(context: context, headers: header(for: key), codingPath: nextPath(for: key))
        return try T(from: decoder)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        return try .init(CSVKeyedDecodingContainer<NestedKey>(context: context, headers: header(for: key), codingPath: nextPath(for: key)))
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(context: context, headers: header(for: key), codingPath: nextPath(for: key))
    }
    
    func superDecoder() throws -> Decoder {
        return try CSVInternalDecoder(context: context, headers: header(for: SuperCodingKey()), codingPath: nextPath(for: SuperCodingKey()))
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        return try CSVInternalDecoder(context: context, headers: header(for: key), codingPath: nextPath(for: key))
    }
}

private struct CSVUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let context: DecodingContext, headers: Trie, codingPath: [CodingKey]
    
    let count: Int?
    var currentIndex = 0
    var isAtEnd: Bool { return currentIndex == count }
    
    init(context: DecodingContext, headers: Trie, codingPath: [CodingKey]) throws {
        self.context = context
        self.headers = headers
        self.codingPath = codingPath
        
        let candidates = headers.keys.compactMap { Int($0) }.sorted()
        
        var count = 0
        for i in candidates {
            if i == count {
                count += 1
            } else {
                break
            }
        }
        self.count = count
    }

    private mutating func nextHeader() throws -> Trie {
        let key = currentKey()
        guard let result = headers[key] else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Key not found"))
        }
        currentIndex += 1
        return result
    }
    
    private mutating func currentKey() -> CodingKey {
        return UnkeyedCodingKey(intValue: currentIndex)
    }
    private mutating func currentPath() -> [CodingKey] {
        return codingPath + [currentKey()]
    }
    
    mutating func decodeNil() throws -> Bool {
        let isNil = try decode(String.self).isEmpty
        if !isNil {
            currentIndex -= 1
        }
        return isNil
    }
    
    mutating func decode(_ type: String.Type) throws -> String {
        guard let index = try nextHeader().value else {
            throw DecodingError.keyNotFound(currentKey(), .init(codingPath: codingPath, debugDescription: "Key not found"))
        }
        return context.value(at: index)
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable, T: LosslessStringConvertible {
        let string = try decode(String.self)
        guard let result = T(string) else {
            throw DecodingError.typeMismatch(Double.self, .init(codingPath: currentPath(), debugDescription: ""))
        }
        return result
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let header = try nextHeader()
        let decoder = CSVInternalDecoder(context: context, headers: header, codingPath: currentPath())
        return try T(from: decoder)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let header = try nextHeader()
        return KeyedDecodingContainer(CSVKeyedDecodingContainer(context: context, headers: header, codingPath: currentPath()))
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let header = try nextHeader()
        return try CSVUnkeyedDecodingContainer(context: context, headers: header, codingPath: currentPath())
    }
    
    mutating func superDecoder() throws -> Decoder {
        let header = try nextHeader()
        return CSVInternalDecoder(context: context, headers: header, codingPath: currentPath())
    }
}

private struct CSVSingleValueDecodingContainer: SingleValueDecodingContainer {
    let context: DecodingContext, headers: Trie, codingPath: [CodingKey]
    
    func decodeNil() -> Bool {
        let isNil = try? decode(String.self).isEmpty
        return isNil ?? true
    }
    
    func decode(_ type: String.Type) throws -> String {
        guard let index = headers.value else {
            throw DecodingError.keyNotFound(codingPath.last ?? UnkeyedCodingKey(intValue: 0), .init(codingPath: codingPath.dropLast(), debugDescription: "Key not found"))
        }
        return context.value(at: index)
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable, T: LosslessStringConvertible {
        let string = try decode(String.self)
        guard let result = T(string) else {
            throw DecodingError.typeMismatch(Double.self, .init(codingPath: codingPath, debugDescription: ""))
        }
        return result
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let decoder = CSVInternalDecoder(context: context, headers: headers, codingPath: codingPath)
        return try T(from: decoder)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        return KeyedDecodingContainer(CSVKeyedDecodingContainer(context: context, headers: headers, codingPath: codingPath))
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try CSVUnkeyedDecodingContainer(context: context, headers: headers, codingPath: codingPath)
    }
    
    mutating func superDecoder() throws -> Decoder {
        return CSVInternalDecoder(context: context, headers: headers, codingPath: codingPath)
    }
}

