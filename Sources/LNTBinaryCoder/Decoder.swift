//
//  Decoder.swift
//  LNTBinaryCoder
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

import Foundation

class DecodingContext {
    let decoder: BinaryDecoder
    var data: Data

    var userInfo: [CodingUserInfoKey: Any] { return decoder.userInfo }

    init(decoder: BinaryDecoder, data: Data) {
        self.decoder = decoder
        self.data = data
    }

    func readValue<T>(codingPath: [CodingKey]) throws -> T where T: FixedWidthInteger {
        guard MemoryLayout<T>.size <= data.count else {
            throw DecodingError.valueNotFound(T.self, .init(codingPath: codingPath, debugDescription: "Reached the end of data stream"))
        }

        var result: T = 0
        withUnsafeMutableBytes(of: &result) {
            assert($0.count == MemoryLayout<T>.size)
            $0.copyBytes(from: data.prefix(MemoryLayout<T>.size))
        }
        data.removeFirst(MemoryLayout<T>.size)

        return result
    }
}

struct BinaryInternalDecoder: Decoder {
    let context: DecodingContext, codingPath: [CodingKey]

    var userInfo: [CodingUserInfoKey : Any] { return context.userInfo }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        preconditionFailure("Keyed Container is not supported.")
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return BinaryUnkeyedValueDecodingContainer(context: context, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return BinarySingleValueDecodingContainer(context: context, codingPath: codingPath)
    }
}

struct BinaryUnkeyedValueDecodingContainer: UnkeyedDecodingContainer {
    let context: DecodingContext, codingPath: [CodingKey]

    let count: Int? = nil
    var isAtEnd: Bool { fatalError("Dynamic unkeyed container is not supported.") }
    var currentIndex = 0

    init(context: DecodingContext, codingPath: [CodingKey]) {
        self.context = context
        self.codingPath = codingPath
    }

    mutating func consumeCodingPath() -> [CodingKey] {
        defer { currentIndex += 1 }
        return codingPath + [UnkeyedCodingKey(intValue: currentIndex)]
    }
    mutating func consumeDecoder() -> BinaryInternalDecoder {
        return .init(context: context, codingPath: consumeCodingPath())
    }

    mutating func decodeNil() throws -> Bool { return false }
    mutating func decode(_ type: Bool.Type) throws -> Bool { return try decode(UInt8.self) != 0 }
    mutating func decode(_ type: Double.Type) throws -> Double { return .init(bitPattern: try decode(UInt64.self)) }
    mutating func decode(_ type: Float.Type) throws -> Float { return .init(bitPattern: try decode(UInt32.self)) }
    mutating func decode(_ type: Int.Type) throws -> Int { return try .init(decode(Int64.self)) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { return try .init(decode(UInt64.self)) }

    mutating func decode(_ type: String.Type) throws -> String {
        preconditionFailure("Decoding \(String.self) is not supported.")
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable, T: FixedWidthInteger {
        return try context.readValue(codingPath: consumeCodingPath())
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        return try .init(from: consumeDecoder())
    }

    mutating func superDecoder() throws -> Decoder {
        return consumeDecoder()
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        preconditionFailure("Keyed container is not supported.")
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return BinaryUnkeyedValueDecodingContainer(context: context, codingPath: consumeCodingPath())
    }
}

struct BinarySingleValueDecodingContainer: SingleValueDecodingContainer {
    let context: DecodingContext, codingPath: [CodingKey]

    func decodeNil() -> Bool { return false }
    func decode(_ type: Bool.Type) throws -> Bool { return try decode(UInt8.self) != 0 }
    func decode(_ type: Double.Type) throws -> Double { return .init(bitPattern: try decode(UInt64.self)) }
    func decode(_ type: Float.Type) throws -> Float { return .init(bitPattern: try decode(UInt32.self)) }
    func decode(_ type: Int.Type) throws -> Int { return try .init(decode(Int64.self)) }
    func decode(_ type: UInt.Type) throws -> UInt { return try .init(decode(UInt64.self)) }

    func decode(_ type: String.Type) throws -> String {
        preconditionFailure("Decoding \(String.self) is not supported.")
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable, T: FixedWidthInteger {
        return try context.readValue(codingPath: codingPath)
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        return try .init(from: BinaryInternalDecoder(context: context, codingPath: codingPath))
    }
}
