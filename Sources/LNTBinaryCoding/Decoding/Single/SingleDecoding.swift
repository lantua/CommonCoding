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
    func decode<T>(_: T.Type) throws -> T where T : Decodable {
        try T(from: InternalDecoder(parsed: (header, data), context: context))
    }
}

struct NilDecodingContainer: BasicDecodingContainer {
    let context: DecodingContext

    var header: Header { .nil }
    var data: Data { Data() }

    func decode<T>(_: T.Type) throws -> T where T: Decodable, T: FixedWidthInteger {
        throw DecodingError.typeMismatch(T.self, context.error("Nil container found"))
    }

    func decode(_: String.Type) throws -> String {
        throw DecodingError.typeMismatch(String.self, context.error("Nil container found"))
    }
}

struct SignedDecodingContainer: BasicDecodingContainer {
    let data: Data, context: DecodingContext

    var header: Header { .signed }

    func decode<T>(_: T.Type) throws -> T where T: Decodable, T: FixedWidthInteger {
        guard 0 < data.count else {
            throw DecodingError.dataCorrupted(context.error("Container is too small"))
        }

        guard T.isSigned else {
            throw DecodingError.typeMismatch(T.self, context.error("Signed integer container found"))
        }

        var result: T = 0
        var littleEndian = data.prefix(T.bitWidth / 8)
        do {
            let byte = littleEndian.removeLast()
            result = T(Int8(bitPattern: byte))
        }

        for byte in littleEndian.reversed() {
            result <<= 8
            result += T(byte)
        }
        return result
    }
    func decode(_: String.Type) throws -> String {
        throw DecodingError.typeMismatch(String.self, context.error("Signed integer container found"))
    }
}

struct UnsignedDecodingContainer: BasicDecodingContainer {
    let data: Data, context: DecodingContext

    var header: Header { .unsigned }

    func decode<T>(_: T.Type) throws -> T where T: Decodable, T: FixedWidthInteger {
        guard 0 < data.count else {
            throw DecodingError.dataCorrupted(context.error("Container is too small"))
        }

        guard !T.isSigned else {
            throw DecodingError.typeMismatch(T.self, context.error("Unsigned integer container found"))
        }

        var result: T = 0
        for byte in data.prefix(T.bitWidth / 8).reversed() {
            result <<= 8
            result += T(byte)
        }
        return result
    }
    func decode(_: String.Type) throws -> String {
        throw DecodingError.typeMismatch(String.self, context.error("Unsigned integer container found"))
    }
}

struct StringDecodingContainer: BasicDecodingContainer {
    let data: Data, context: DecodingContext

    var header: Header { .string }

    func decode<T>(_: T.Type) throws -> T where T : Decodable {
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
