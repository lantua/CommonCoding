//
//  InternalDecoder.swift
//  LNTBinaryCoding
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

import Foundation
import LNTSharedCoding

// MARK: Context

struct SharedDecodingContext {
    let strings: [String]

    init(data: inout Data) throws {
        guard data.count >= 2 else {
            throw BinaryDecodingError.emptyFile
        }

        guard data.removeFirst() == 0x00,
            data.removeFirst() == 0x00 else {
                throw BinaryDecodingError.invalidFileVersion
        }

        let count = try data.extractVSUI()
        self.strings = try (0..<count).map { _ in
            try data.extractString()
        }
    }
}

extension CodingContext where Shared == SharedDecodingContext {
    func string(at index: Int) throws -> String {
        let index = index - 1
        guard shared.strings.indices ~= index else {
            throw BinaryDecodingError.invalidStringMapIndex
        }
        return shared.strings[index]
    }
}

// MARK: Encoder

struct InternalDecoder: ContextContainer, Decoder {
    var header: Header, data: Data
    public var context: CodingContext<SharedDecodingContext>

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        try .init(KeyedBinaryDecodingContainer(decoder: self))
    }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer { try UnkeyedBinaryDecodingContainer(decoder: self) }
    func singleValueContainer() throws -> SingleValueDecodingContainer { self }
}

extension InternalDecoder {
    init(data: Data, userInfo: [CodingUserInfoKey: Any]) throws {
        var data = data
        context = try .init(.init(data: &data), userInfo: userInfo)
        header = try data.extractHeader()
        self.data = data
    }
}

// MARK: Keyed Container

private struct KeyedBinaryDecodingContainer<Key>: ContextContainer, KeyedDecodingContainerProtocol where Key: CodingKey {
    let values: [String: Data], sharedHeader: Header?, context: CodingContext<SharedDecodingContext>

    init(decoder: InternalDecoder) throws {
        self.context = decoder.context

        var data = decoder.data
        var tmp: [String: Data] = [:]

        switch decoder.header {
        case let .regularKeyed(header):
            for (key, size) in header.mapping {
                guard data.count >= size else {
                    throw BinaryDecodingError.containerTooSmall
                }
                try tmp[context.string(at: key)] = data.prefix(size)
                data.removeFirst(size)
            }
            sharedHeader = nil
        case let .equisizeKeyed(header):
            let size = header.payloadSize
            guard data.count >= size * header.keys.count else {
                throw BinaryDecodingError.containerTooSmall
            }
            for key in header.keys {
                try tmp[context.string(at: key)] = data.prefix(size)
                data.removeFirst(size)
            }
            sharedHeader = header.subheader
        default: throw DecodingError.typeMismatch(KeyedDecodingContainer<Key>.self, context.error("Incompatible container found"))
        }
        values = tmp
    }

    var allKeys: [Key] { values.keys.compactMap(Key.init(stringValue:)) }
    func contains(_ key: Key) -> Bool { values.keys.contains(key.stringValue) }

    private func decoder(for key: CodingKey) throws -> InternalDecoder {
        guard var data = values[key.stringValue] else {
            throw DecodingError.keyNotFound(key, context.error())
        }
        let header = try sharedHeader ?? data.extractHeader()
        return .init(header: header, data: data, context: context.appending(key))
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard var data = values[key.stringValue] else {
            return true
        }
        return try (sharedHeader ?? data.extractHeader()).isNil
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable { try T(from: decoder(for: key)) }
    func superDecoder() throws -> Decoder { try decoder(for: SuperCodingKey()) }
    func superDecoder(forKey key: Key) throws -> Decoder { try decoder(for: key) }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer { try decoder(for: key).unkeyedContainer() }
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try decoder(for: key).container(keyedBy: NestedKey.self)
    }
}

// MARK: Unkeyed Container

private struct UnkeyedBinaryDecodingContainer: ContextContainer, UnkeyedDecodingContainer {
    private var values: ArraySlice<Data>
    let sharedHeader: Header?, context: CodingContext<SharedDecodingContext>

    let count: Int?
    var currentIndex = 0

    init(decoder: InternalDecoder) throws {
        self.context = decoder.context

        var tmp: [Data] = [], data = decoder.data
        switch decoder.header {
        case let .regularUnkeyed(header):
            tmp.reserveCapacity(header.sizes.count)
            for size in header.sizes {
                guard data.count >= size else {
                    throw BinaryDecodingError.containerTooSmall
                }
                tmp.append(data.prefix(size))
                data.removeFirst(size)
            }
            sharedHeader = nil
        case let .equisizeUnkeyed(header):
            tmp.reserveCapacity(header.count)
            let size = header.payloadSize
            guard data.count >= size * header.count else {
                throw BinaryDecodingError.containerTooSmall
            }
            for _ in 0..<header.count {
                tmp.append(data.prefix(size))
                data.removeFirst(size)
            }
            sharedHeader = header.subheader
        default: throw DecodingError.typeMismatch(UnkeyedDecodingContainer.self, context.error("Incompatible container found"))
        }
        values = tmp[...]
        count = values.count
    }

    var isAtEnd: Bool { values.isEmpty }

    mutating func consumeDecoder() throws -> InternalDecoder {
        guard !isAtEnd else {
            throw DecodingError.keyNotFound(UnkeyedCodingKey(intValue: currentIndex), context.error("End of container reached"))
        }

        defer { currentIndex += 1 }
        var data = values.removeFirst()
        let header = try sharedHeader ?? data.extractHeader()
        return .init(header: header, data: data, context: context.appending(UnkeyedCodingKey(intValue: currentIndex)))
    }

    mutating func decodeNil() throws -> Bool {
        guard var data = values.first else {
            return true
        }
        return try (sharedHeader ?? data.extractHeader()).isNil
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable { try T(from: consumeDecoder()) }
    mutating func superDecoder() throws -> Decoder { try consumeDecoder() }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer { try consumeDecoder().unkeyedContainer() }
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try consumeDecoder().container(keyedBy: NestedKey.self)
    }
}

// MARK: Single Value Container

extension InternalDecoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        if case .nil = header {
            return true
        }
        return false
    }
    func decode(_: Bool.Type) throws -> Bool { try decode(UInt8.self) != 0 }
    func decode(_: Float.Type) throws -> Float { try Float(bitPattern: decode(UInt32.self)) }
    func decode(_: Double.Type) throws -> Double { try Double(bitPattern: decode(UInt64.self)) }

    func decode<T>(_: T.Type) throws -> T where T: Decodable, T: FixedWidthInteger {
        let tmp: T?
        switch header {
        case .signed: tmp = data.readSigned(T.self)
        case .unsigned: tmp = data.readUnsigned(T.self)
        default: throw DecodingError.typeMismatch(T.self, context.error("Incompatible container"))
        }

        guard let result = tmp else {
            throw DecodingError.typeMismatch(T.self, context.error("Value out of range"))
        }
        return result
    }

    func decode(_: String.Type) throws -> String {
        guard case .string = header else {
            throw DecodingError.typeMismatch(String.self, context.error("Incompatible container"))
        }

        return try context.string(at: data.readVSUI())
    }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable { try T(from: self) }
}
