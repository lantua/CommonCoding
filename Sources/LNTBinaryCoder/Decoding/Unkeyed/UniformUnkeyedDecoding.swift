//
//  UniformUnkeyedDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 17/2/2563 BE.
//

import Foundation

struct UniformUnkeyedDecodingContainer: CommonUnkeyedDecodingContainer {
    let context: DecodingContext

    let subheader: Header, size: Int, count: Int?
    var data: Data, currentIndex = 0

    init(header: UniformUnkeyedHeader, data: Data, context: DecodingContext) throws {
        guard header.payloadSize <= data.count else {
            throw BinaryDecodingError.containerTooSmall
        }

        self.context = context
        self.data = data
        self.size = header.size - header.subheader.size
        self.count = header.count
        self.subheader = header.subheader
    }
}

extension UniformUnkeyedDecodingContainer {
    mutating func currentBlock(consume: Bool) throws -> HeaderData {
        assert(!isAtEnd)
        
        var data = self.data
        defer {
            if consume {
                self.data = data
            }
        }
        return (subheader, data.consumeBlock(size: size))
    }
}

private extension Data {
    mutating func consumeBlock(size: Int) -> Data {
        assert(count >= size)

        defer { removeFirst(size) }
        return prefix(size)
    }
}

extension UniformUnkeyedDecodingContainer {
    var isAtEnd: Bool { currentIndex == count }
}
