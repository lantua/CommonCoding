//
//  Public.swift
//  LNTBinaryCoder
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

import Foundation

public struct BinaryDecoder {
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
        let context = DecodingContext(decoder: self, data: data)
        let decoder = BinaryInternalDecoder(context: context, codingPath: [])
        return try .init(from: decoder)
    }
}

public struct BinaryEncoder {
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public func encode<S>(_ value: S) throws -> Data where S: Encodable {
        let context = EncodingContext(encoder: self)
        let encoder = BinaryInternalEncoder(context: context, codingPath: [])
        try value.encode(to: encoder)
        return context.data
    }
}
