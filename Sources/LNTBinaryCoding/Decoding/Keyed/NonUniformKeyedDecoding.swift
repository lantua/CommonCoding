//
//  NonUniformKeyedDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 16/2/2563 BE.
//

import Foundation

struct NonUniformKeyedDecodingContainer<Key>: CommonKeyedDecodingContainer where Key: CodingKey {
    let context: DecodingContext, list: [String: Data]

    init(header: RegularKeyedHeader, data: Data, context: DecodingContext) throws {
        guard header.mapping.lazy.map({ $0.size }).reduce(0, +) <= data.count else {
            throw BinaryDecodingError.containerTooSmall
        }

        self.context = context
        var current = 0
        self.list = try Dictionary(header.mapping.lazy.compactMap {
            let key = try context.string(at: $0.key), next = current + $0.size
            defer { current = next }
            return Key(stringValue: key) != nil || key == "super" ? (key, data[offset: current..<next]) : nil
        }) { $1 }
    }

    init(header: EquisizedKeyedHeader, data: Data, context: DecodingContext) throws {
        guard header.payloadSize <= data.count else {
            throw DecodingError.dataCorrupted(context.error("Container is too small"))
        }

        let size = header.size
        var data = data

        self.context = context
        self.list = try Dictionary(header.keys.lazy.compactMap { keyIndex in
            let key = try context.string(at: keyIndex)
            defer { data.removeFirst(size) }
            return Key(stringValue: key) != nil || key == "super" ? (key, data.prefix(size)) : nil
        }) { $1 }
    }
}

extension NonUniformKeyedDecodingContainer {
    func block(forKey key: CodingKey) throws -> HeaderData {
        guard let data = list[key.stringValue] else {
            throw DecodingError.keyNotFound(key, context.error())
        }

        do {
            return try data.splitHeader()
        } catch {
            throw DecodingError.dataCorrupted(context.error(error: error))
        }
    }
    var allKeys: [Key] { list.keys.map { Key(stringValue: $0)! } }

    func contains(_ key: Key) -> Bool { list.keys.contains(key.stringValue) }
}
