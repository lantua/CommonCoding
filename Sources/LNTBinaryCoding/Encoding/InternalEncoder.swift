//
//  InternalEncoder.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation

struct InternalEncoder: Encoder {
    let parent: TemporaryEncodingStorageWriter, context: EncodingContext

    var userInfo: [CodingUserInfoKey : Any] { context.userInfo }
    var codingPath: [CodingKey] { context.codingPath }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        .init(KeyedBinaryEncodingContainer(parent: parent, context: context))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        UnkeyedBinaryEncodingContainer(parent: parent, context: context)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        SingleValueBinaryEncodingContainer(parent: parent, context: context)
    }
}
