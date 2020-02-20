//
//  InternalEncoder.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation

class InternalEncoder: Encoder {
    let storage: SingleValueStorage, context: EncodingContext

    var userInfo: [CodingUserInfoKey : Any] { context.userInfo }
    var codingPath: [CodingKey] { context.codingPath }

    init(storage: SingleValueStorage, context: EncodingContext) {
        self.storage = storage
        self.context = context
    }

    private func register<T>(_ value: T) -> T where T: TemporaryEncodingStorage {
        storage.value = value
        return value
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        .init(KeyedBinaryEncodingContainer(storage: register(.init()), context: context))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        UnkeyedBinaryEncodingContainer(storage: register(.init()), context: context)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        SingleValueBinaryEncodingContainer(storage: storage, context: context)
    }

    deinit {
        storage.value = storage.finalize()
    }
}
