//
//  CommonUnkeyedDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 16/2/2563 BE.
//

import Foundation
import LNTSharedCoding

protocol CommonUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    var context: DecodingContext { get }
    var currentIndex: Int { get set }

    /// Returns the block for the current element. Advance to the next block if `consume` is `true`.
    mutating func currentBlock(consume: Bool) throws -> HeaderData
}

extension CommonUnkeyedDecodingContainer {
    var codingPath: [CodingKey] { context.codingPath }

    private mutating func consumeDecoder() throws -> InternalDecoder {
        guard !isAtEnd else {
            throw DecodingError.keyNotFound(UnkeyedCodingKey(intValue: currentIndex), context.error("End of container reached"))
        }
        defer { currentIndex += 1 }
        return try InternalDecoder(parsed: currentBlock(consume: true), context: context.appending(UnkeyedCodingKey(intValue: currentIndex)))
    }

    mutating func decodeNil() throws -> Bool { try isAtEnd ? false : currentBlock(consume: false).header.tag == .nil }
    mutating func decode<T>(_: T.Type) throws -> T where T: Decodable { try T(from: consumeDecoder()) }

    mutating func superDecoder() throws -> Decoder { try consumeDecoder() }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer { try consumeDecoder().unkeyedContainer() }
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try consumeDecoder().container(keyedBy: NestedKey.self)
    }
}
