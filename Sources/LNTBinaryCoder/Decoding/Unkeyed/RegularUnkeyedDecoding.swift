//
//  RegularUnkeyedDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 16/2/2563 BE.
//

import Foundation

struct RegularUnkeyedDecodingContainer: CommonUnkeyedDecodingContainer {
    let context: DecodingContext, count: Int?

    var data: Data, sizes: ArraySlice<Int>, currentIndex = 0

    init(header: RegularUnkeyedHeader, data: Data, context: DecodingContext) throws {
        guard header.sizes.reduce(0, +) <= data.count else {
            throw BinaryDecodingError.containerTooSmall
        }

        self.context = context
        self.sizes = header.sizes[...]
        self.count = sizes.count
        self.data = data
    }
}

extension RegularUnkeyedDecodingContainer {
    mutating func currentBlock(consume: Bool) throws -> HeaderData {
        assert(!isAtEnd)

        var data = self.data
        defer {
            if consume {
                self.data = data
                self.sizes.removeFirst()
            }
        }
        do {
            return try data.consumeBlock(size: sizes.first!)
        } catch {
            throw DecodingError.dataCorrupted(context.error(error: error))
        }
    }
}

private extension Data {
    mutating func consumeBlock(size: Int) throws -> HeaderData {
        assert(count >= size)
        defer { removeFirst(size) }
        return try prefix(size).splitHeader()
    }
}

extension RegularUnkeyedDecodingContainer {
    var isAtEnd: Bool { sizes.isEmpty }
}
