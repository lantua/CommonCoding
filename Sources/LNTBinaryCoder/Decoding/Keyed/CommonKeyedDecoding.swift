//
//  CommonKeyedDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation

protocol CommonKeyedDecodingContainer: KeyedDecodingContainerProtocol {
    var context: DecodingContext { get }

    func header(forKey key: CodingKey) throws -> HeaderData
}

extension CommonKeyedDecodingContainer {
    var codingPath: [CodingKey] { context.codingPath }

    private func decoder(forKey key: CodingKey) throws -> InternalDecoder {
        try InternalDecoder(parsed: header(forKey: key), context: context.appending(key))
    }

    func decodeNil(forKey key: Key) throws -> Bool { try header(forKey: key).header.tag == .nil }
    func decode<T>(_: T.Type, forKey key: Key) throws -> T where T: Decodable { try T(from: decoder(forKey: key)) }

    func superDecoder() throws -> Decoder { try decoder(forKey: SuperCodingKey()) }
    func superDecoder(forKey key: Key) throws -> Decoder { try decoder(forKey: key) }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer { try decoder(forKey: key).unkeyedContainer() }
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try decoder(forKey: key).container(keyedBy: NestedKey.self)
    }
}
