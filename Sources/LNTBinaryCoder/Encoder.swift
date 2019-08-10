//
//  Encoder.swift
//  LNTBinaryCoder
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

import Foundation

class EncodingContext {
    let encoder: BinaryEncoder
    var data = Data()

    var userInfo: [CodingUserInfoKey: Any] { return encoder.userInfo }

    init(encoder: BinaryEncoder) {
        self.encoder = encoder
    }

    func write<T>(_ value: T, codingPath: [CodingKey]) throws where T: FixedWidthInteger {
        withUnsafeBytes(of: value) {
            assert($0.count == MemoryLayout<T>.size)
            data.append($0.bindMemory(to: T.self))
        }
    }
}

struct BinaryInternalEncoder: Encoder {
    let context: EncodingContext, codingPath: [CodingKey]

    var userInfo: [CodingUserInfoKey : Any] { return context.userInfo }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        preconditionFailure("Keyed container is not supported.")
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return BinaryUnkeyedEncodingContainer(context: context, codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return BinarySingleValueEncodingContainer(context: context, codingPath: codingPath)
    }
}

struct BinaryUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let context: EncodingContext, codingPath: [CodingKey]

    var count = 0

    init(context: EncodingContext, codingPath: [CodingKey]) {
        self.context = context
        self.codingPath = codingPath
    }

    mutating func consumeCodingPath() -> [CodingKey] {
        defer { count += 1 }
        return codingPath + [UnkeyedCodingKey(intValue: count)]
    }
    mutating func consumeEncoder() -> BinaryInternalEncoder {
        return .init(context: context, codingPath: consumeCodingPath())
    }

    mutating func encodeNil() throws {
        preconditionFailure("Encoding `nil` is not supported.")
    }


    mutating func encode(_ value: String) throws {
        preconditionFailure("Encoding \(String.self) is not supported.")
    }

    mutating func encode(_ value: Bool) throws { try encode(value ? 1 : 0 as UInt8) }
    mutating func encode(_ value: Double) throws { try encode(value.bitPattern) }
    mutating func encode(_ value: Float) throws { try encode(value.bitPattern) }
    mutating func encode(_ value: Int) throws { try encode(Int64(value)) }
    mutating func encode(_ value: UInt) throws { try encode(UInt64(value)) }

    mutating func encode<T>(_ value: T) throws where T: Encodable, T: FixedWidthInteger {
        try context.write(value, codingPath: consumeCodingPath())
    }

    mutating func encode<T>(_ value: T) throws where T : Encodable { try value.encode(to: consumeEncoder()) }
    mutating func superEncoder() -> Encoder { return consumeEncoder() }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        preconditionFailure("Keyed container is not supported.")
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return BinaryUnkeyedEncodingContainer(context: context, codingPath: consumeCodingPath())
    }
}

struct BinarySingleValueEncodingContainer: SingleValueEncodingContainer {
    let context: EncodingContext, codingPath: [CodingKey]

    mutating func encodeNil() throws {
        preconditionFailure("Encoding `nil` is not supported.")
    }

    mutating func encode(_ value: String) throws {
        preconditionFailure("Encoding \(String.self) is not supported.")
    }

    mutating func encode(_ value: Bool) throws { try encode(value ? 1 : 0 as UInt8) }
    mutating func encode(_ value: Double) throws { try encode(value.bitPattern) }
    mutating func encode(_ value: Float) throws { try encode(value.bitPattern) }
    mutating func encode(_ value: Int) throws { try encode(Int64(value)) }
    mutating func encode(_ value: UInt) throws { try encode(UInt64(value)) }

    mutating func encode<T>(_ value: T) throws where T: Encodable, T: FixedWidthInteger {
        try context.write(value, codingPath: codingPath)
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        try value.encode(to: BinaryInternalEncoder(context: context, codingPath: codingPath))
    }
}
