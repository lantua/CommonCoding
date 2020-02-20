//
//  EquisizedUnkeyedDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 16/2/2563 BE.
//

import Foundation

struct EquisizedUnkeyedDecodingContainer: CommonUnkeyedDecodingContainer {
    let context: DecodingContext, size: Int
    var data: Data, currentIndex = 0

    init(header: EquisizedUnkeyedHeader, data: Data, context: DecodingContext) {
        self.context = context
        self.size = header.size
        self.data = data
    }
}

extension EquisizedUnkeyedDecodingContainer {
    mutating func currentBlock(consume: Bool) throws -> HeaderData {
        assert(!isAtEnd)

        var data = self.data
        defer {
            if consume {
                self.data = data
            }
        }
        do {
            return try data.consumeBlock(size: size)
        } catch {
            throw DecodingError.dataCorrupted(context.error(error: error))
        }
    }
}

private extension Data {
    mutating func consumeBlock(size: Int) throws -> HeaderData {
        guard count >= size else {
            throw BinaryDecodingError.containerTooSmall
        }

        defer { removeFirst(size) }
        return try prefix(size).splitHeader()
    }
}

extension EquisizedUnkeyedDecodingContainer {
    var count: Int? { nil }

    var isAtEnd: Bool { data.first ?? 0 == 0 }
}
