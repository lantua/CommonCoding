//
//  UnkeyedDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 22/2/2563 BE.
//

import Foundation
import LNTSharedCoding

struct UnkeyedBinaryDecodingContainer<C>: UnkeyedDecodingContainer where C: Collection, C.Element == Int {
    let context: DecodingContext, subheader: Header?, count: Int?
    var sizes: C.SubSequence, data: Data, currentIndex = 0
}

extension UnkeyedBinaryDecodingContainer where C == Array<Int> {
    init(header: RegularUnkeyedHeader, data: Data, context: DecodingContext) throws {
        guard header.totalPayloadSize <= data.count else {
            throw BinaryDecodingError.containerTooSmall
        }

        self.context = context
        self.subheader = nil
        self.count = header.sizes.count
        self.sizes = header.sizes[...]
        self.data = data
    }
}

extension UnkeyedBinaryDecodingContainer where C == Repeated<Int> {
    init(header: EquisizedUnkeyedHeader, data: Data, context: DecodingContext) throws {
        guard header.totalPayloadSize <= data.count else {
            throw BinaryDecodingError.containerTooSmall
        }

        self.context = context
        self.subheader = nil
        self.count = header.count
        self.sizes = repeatElement(header.size, count: header.count)[...]
        self.data = data
    }

    init(header: UniformUnkeyedHeader, data: Data, context: DecodingContext) throws {
        guard header.totalPayloadSize <= data.count else {
            throw BinaryDecodingError.containerTooSmall
        }

        self.context = context
        self.subheader = header.subheader
        self.count = header.count
        self.sizes = repeatElement(header.payloadSize, count: header.count)[...]
        self.data = data
    }
}

extension UnkeyedBinaryDecodingContainer {
    var codingPath: [CodingKey] { context.codingPath }

    var isAtEnd: Bool { sizes.isEmpty }

    private mutating func consumeDecoder() throws -> InternalDecoder {
        guard !isAtEnd else {
            throw DecodingError.keyNotFound(UnkeyedCodingKey(intValue: currentIndex), context.error("End of container reached"))
        }
        defer { currentIndex += 1 }
        return try InternalDecoder(parsed: consumeBlock(), context: context.appending(UnkeyedCodingKey(intValue: currentIndex)))
    }

    mutating func decodeNil() throws -> Bool {
        guard let size = sizes.first else {
            return true
        }

        if let header = subheader {
            return header.tag == .nil
        }
        do {
            return try data.prefix(size).splitHeader().header.tag == .nil
        } catch {
            throw DecodingError.dataCorrupted(context.error())
        }
    }
    mutating func decode<T>(_: T.Type) throws -> T where T: Decodable { try T(from: consumeDecoder()) }

    mutating func superDecoder() throws -> Decoder { try consumeDecoder() }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer { try consumeDecoder().unkeyedContainer() }
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try consumeDecoder().container(keyedBy: NestedKey.self)
    }
}

extension UnkeyedBinaryDecodingContainer {
    mutating func consumeBlock() throws -> HeaderData {
        assert(!isAtEnd)

        let size = sizes.removeFirst()
        defer { data.removeFirst(size) }
        
        if let subheader = subheader {
            return (subheader, data.prefix(size))
        }
        do {
            return try data.prefix(size).splitHeader()
        } catch {
            throw DecodingError.dataCorrupted(context.error(error: error))
        }
    }
}
