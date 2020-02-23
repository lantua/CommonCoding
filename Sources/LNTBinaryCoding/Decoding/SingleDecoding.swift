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
}

extension BasicDecodingContainer {
    var codingPath: [CodingKey] { context.codingPath }

    func decodeNil() -> Bool { Self.self == NilDecodingContainer.self } // This is a little hackey, but should be fine for the moment.
    func decode(_: Bool.Type) throws -> Bool { try decode(UInt8.self) != 0 }
    func decode(_: Float.Type) throws -> Float { try Float(bitPattern: decode(UInt32.self)) }
    func decode(_: Double.Type) throws -> Double { try Double(bitPattern: decode(UInt64.self)) }
    func decode<T>(_: T.Type) throws -> T where T : Decodable {
        try T(from: InternalDecoder(container: self, context: context))
    }
}

struct NilDecodingContainer: BasicDecodingContainer {
    let context: DecodingContext

    func decode<T>(_: T.Type) throws -> T where T: Decodable, T: FixedWidthInteger {
        throw DecodingError.typeMismatch(T.self, context.error("Nil container found"))
    }

    func decode(_: String.Type) throws -> String {
        throw DecodingError.typeMismatch(String.self, context.error("Nil container found"))
    }
}

struct IntegerDecodingContainer<Value>: BasicDecodingContainer where Value: BinaryInteger {
    let value: Value, context: DecodingContext

    func decode<T>(_: T.Type) throws -> T where T: Decodable, T: BinaryInteger {
        guard let result = T(exactly: value) else {
            throw DecodingError.typeMismatch(T.self, context.error("Trying to decode \(value)"))
        }

        return result
    }
    func decode(_: String.Type) throws -> String {
        throw DecodingError.typeMismatch(String.self, context.error("Signed integer container found"))
    }
}

func signedDecodingContainer(data: Data, context: DecodingContext) throws -> SingleValueDecodingContainer {
    switch data.count {
    case 0: throw BinaryDecodingError.containerTooSmall
    case 1..<2: return IntegerDecodingContainer(value: data.readFixedWidth(Int8.self), context: context)
    case 2..<4: return IntegerDecodingContainer(value: data.readFixedWidth(Int16.self), context: context)
    case 4..<8: return IntegerDecodingContainer(value: data.readFixedWidth(Int32.self), context: context)
    default: return IntegerDecodingContainer(value: data.readFixedWidth(Int64.self), context: context)
    }
}

func unsignedDecodingContainer(data: Data, context: DecodingContext) throws -> SingleValueDecodingContainer {
    switch data.count {
    case 0: throw BinaryDecodingError.containerTooSmall
    case 1..<2: return IntegerDecodingContainer(value: data.readFixedWidth(UInt8.self), context: context)
    case 2..<4: return IntegerDecodingContainer(value: data.readFixedWidth(UInt16.self), context: context)
    case 4..<8: return IntegerDecodingContainer(value: data.readFixedWidth(UInt32.self), context: context)
    default: return IntegerDecodingContainer(value: data.readFixedWidth(UInt64.self), context: context)
    }
}

struct StringDecodingContainer: BasicDecodingContainer {
    let data: Data, context: DecodingContext

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
