//
//  SingleEncoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 16/2/2563 BE.
//

import Foundation

struct SingleValueBinaryEncodingContainer: SingleValueEncodingContainer {
    let parent: TemporaryEncodingStorageWriter, context: EncodingContext

    var codingPath: [CodingKey] { context.codingPath }

    func encodeNil() throws { parent.register(NilStorage()) }

    func encode(_ value: String) throws {
        context.register(string: value)
        parent.register(StringStorage(string: value))
    }

    func encode(_ value: Bool) throws { try encode(value ? 1 : 0 as UInt8) }
    func encode(_ value: Double) throws { try encode(value.bitPattern) }
    func encode(_ value: Float) throws { try encode(value.bitPattern) }

    func encode<T>(_ value: T) throws where T: Encodable, T: FixedWidthInteger, T: SignedInteger {
        parent.register(signedStorage(value: value))
    }
    func encode<T>(_ value: T) throws where T: Encodable, T: FixedWidthInteger, T: UnsignedInteger {
        parent.register(unsignedStorage(value: value))
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        try value.encode(to: InternalEncoder(parent: parent, context: context))
    }
}
