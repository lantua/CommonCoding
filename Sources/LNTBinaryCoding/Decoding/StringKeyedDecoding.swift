//
//  StringKeyedDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 22/2/2563 BE.
//

import Foundation
import LNTSharedCoding

struct StringKeyedDecodingContainer {
    let context: DecodingContext
    private let subheader: Header?, list: [String: Data]

    init<T>(subheader: Header?, context: DecodingContext, list: T) where T: Collection, T.Element == (String, Data) {
        self.context = context
        self.subheader = subheader
        self.list = Dictionary(list) { $1 }
    }

    init(header: RegularKeyedHeader, data: Data, context: DecodingContext) throws {
        guard header.totalPayloadSize <= data.count else {
            throw BinaryDecodingError.containerTooSmall
        }

        var data = data

        try self.init(subheader: nil, context: context, list: header.mapping.lazy.map { arg in
            let key = try context.string(at: arg.key)
            defer { data.removeFirst(arg.size) }
            return (key, data.prefix(arg.size))
        })
    }

    init(header: EquisizeKeyedHeader, data: Data, context: DecodingContext) throws {
        guard header.totalPayloadSize <= data.count else {
            throw BinaryDecodingError.containerTooSmall
        }

        let size = header.size
        var data = data

        try self.init(subheader: nil, context: context, list: header.keys.lazy.map { keyIndex in
            let key = try context.string(at: keyIndex)
            defer { data.removeFirst(size) }
            return (key, data.prefix(size))
        })
    }

    init(header: UniformKeyedHeader, data: Data, context: DecodingContext) throws {
        guard header.totalPayloadSize <= data.count else {
            throw BinaryDecodingError.containerTooSmall
        }

        let payloadSize = header.payloadSize
        var data = data

        try self.init(subheader: header.subheader, context: context, list: header.keys.lazy.map { keyIndex in
            let key = try context.string(at: keyIndex)
            defer { data.removeFirst(payloadSize) }
            return (key, data.prefix(payloadSize))
        })
    }

    var keys: Dictionary<String, Data>.Keys { list.keys }

    func block(for key: CodingKey) throws -> HeaderData {
        guard let data = list[key.stringValue] else {
            throw DecodingError.keyNotFound(key, context.error())
        }

        if let subheader = subheader {
            return (subheader, data)
        }
        do {
            return try data.splitHeader()
        } catch {
            throw DecodingError.dataCorrupted(context.error())
        }
    }
}

struct KeyedBinaryDecodingContainer<Key>: KeyedDecodingContainerProtocol where Key: CodingKey {
    let container: StringKeyedDecodingContainer

    private var context: DecodingContext { container.context }
    var codingPath: [CodingKey] { context.codingPath }

    var allKeys: [Key] { container.keys.compactMap(Key.init(stringValue:)) }

    func contains(_ key: Key) -> Bool { container.keys.contains(key.stringValue) }

    func decodeNil(forKey key: Key) throws -> Bool {
        try !contains(key) || container.block(for: key).header.tag == .nil
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        try T(from: InternalDecoder(parsed: container.block(for: key), context: context.appending(key)))
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try .init(InternalDecoder(parsed: container.block(for: key), context: context.appending(key))
            .container(keyedBy: NestedKey.self))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try InternalDecoder(parsed: container.block(for: key), context: context.appending(key))
            .unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        try InternalDecoder(parsed: container.block(for: SuperCodingKey()), context: context.appending(SuperCodingKey()))
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        try InternalDecoder(parsed: container.block(for: key), context: context.appending(key))
    }
}
