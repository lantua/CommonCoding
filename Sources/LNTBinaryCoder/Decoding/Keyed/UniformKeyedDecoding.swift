//
//  UniformKeyedDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation

struct UniformKeyedDecodingContainer<Key> where Key: CodingKey {
    let context: DecodingContext, subheader: Header, list: [String: Data]

    init(header: UniformKeyedHeader, data: Data, context: DecodingContext) throws {
        guard header.payloadSize <= data.count else {
            throw DecodingError.dataCorrupted(context.error("Container is too small"))
        }

        let payloadSize = header.size - header.subheader.size
        var data = data

        self.context = context
        self.subheader = header.subheader
        self.list = try Dictionary(header.keys.compactMap { keyIndex in
            let key = try context.string(at: keyIndex)
            defer { data.removeFirst(payloadSize) }
            return Key(stringValue: key) != nil || key == "super" ? (key, data.prefix(payloadSize)) : nil
        }) { $1 }
    }
}

extension UniformKeyedDecodingContainer: CommonKeyedDecodingContainer {
    func block(forKey key: CodingKey) throws -> HeaderData {
        guard let data = list[key.stringValue] else {
            throw DecodingError.keyNotFound(key, context.error())
        }

        return (subheader, data)
    }
    var allKeys: [Key] { list.keys.map { Key(stringValue: $0)! } }

    func contains(_ key: Key) -> Bool { list.keys.contains(key.stringValue) }
}
