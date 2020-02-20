//
//  SingleDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 16/2/2563 BE.
//

import Foundation

/// Basic Containers (Nil, Fixed-width, String).
private protocol BasicDecodingContainer: SingleValueDecodingContainer {
    var context: DecodingContext { get }
    var header: Header { get }
    var data: Data { get }
}

extension BasicDecodingContainer {
    var codingPath: [CodingKey] { context.codingPath }

    func decodeNil() -> Bool { header.tag == .nil }
    func decode(_: Bool.Type) throws -> Bool { try decode(UInt8.self) != 0 }
    func decode(_: Float.Type) throws -> Float { try Float(bitPattern: decode(UInt32.self)) }
    func decode(_: Double.Type) throws -> Double { try Double(bitPattern: decode(UInt64.self)) }
    func decode(_: Int.Type) throws -> Int { try Int(decode(Int64.self)) }
    func decode(_: UInt.Type) throws -> UInt { try UInt(decode(UInt64.self)) }
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        try T(from: InternalDecoder(parsed: (header, data), context: context))
    }
}

struct NilDecodingContainer: BasicDecodingContainer {
    let context: DecodingContext

    var header: Header { .nil }
    var data: Data { Data() }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable, T: FixedWidthInteger {
        throw DecodingError.typeMismatch(T.self, context.error("Nil container found"))
    }

    func decode(_: String.Type) throws -> String {
        throw DecodingError.typeMismatch(String.self, context.error("Nil container found"))
    }
}

struct FixedWidthDecodingContainer: BasicDecodingContainer {
    let data: Data, context: DecodingContext

    var header: Header { .fixedWidth }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable, T: FixedWidthInteger {
        guard MemoryLayout<T>.size <= data.count else {
            throw DecodingError.typeMismatch(T.self, context.error("Container is too small"))
        }

        var result: T = 0
        withUnsafeMutableBytes(of: &result) {
            $0.copyBytes(from: data.prefix(MemoryLayout<T>.size))
        }

        return result.littleEndian
    }

    func decode(_: String.Type) throws -> String {
        throw DecodingError.typeMismatch(String.self, context.error("Fixed-width container found"))
    }
}

struct StringDecodingContainer: BasicDecodingContainer {
    let data: Data, context: DecodingContext

    var header: Header { .stringReference }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        throw DecodingError.typeMismatch(T.self, context.error("String container found"))
    }

    func decode(_: String.Type) throws -> String {
        do {
            var data = self.data
            let index = try data.readInteger()
            return try context.string(at: index)
        } catch {
            throw DecodingError.dataCorrupted(context.error(error: error))
        }
    }
}
