//
//  Public.swift
//  LNTBinaryCoding
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

import Foundation

public struct BinaryDecoder {
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public func decode<T>(_: T.Type, from data: Data) throws -> T where T: Decodable {
        return try .init(from: InternalDecoder(data: data, userInfo: userInfo))
    }
}

public struct BinaryEncoder {
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public func encode<S>(_ value: S) throws -> Data where S: Encodable {
        let temp = TopLevelTemporaryEncodingStorage()
        
        let encodingContext = EncodingContext(userInfo: userInfo)
        let encoder = InternalEncoder(parent: temp, context: encodingContext)
        try value.encode(to: encoder)

        let strings = encodingContext.optimize()
        let context = OptimizationContext(strings: strings)

        var storage = temp.value
        storage.optimize(for: context)

        let stringMapSize = strings.count.vsuiSize + strings.lazy.map { $0.utf8.count }.reduce(0, +) + strings.count

        var data = Data(count: 2 + stringMapSize + storage.size)

        data.withUnsafeMutableBytes {
            var data = $0[...]

            func append(_ value: UInt8) {
                data[data.startIndex] = value
                data.removeFirst()
            }

            append(0)
            append(0)
            strings.count.write(to: &data)
            for string in strings {
                let raw = string.utf8
                UnsafeMutableRawBufferPointer(rebasing: data).copyBytes(from: raw)
                data.removeFirst(raw.count)
                append(0)
            }

            storage.write(to: data)
        }
        
        return data
    }
}
