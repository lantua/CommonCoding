//
//  SingleStorage.swift
//  
//
//  Created by Natchanon Luangsomboon on 20/2/2563 BE.
//

import Foundation

struct NilStorage: EncodingStorage {
    var header: Header { .nil }
    var payloadSize: Int { 0 }

    func optimize(for context: OptimizationContext) { }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) { }
}

struct IntegerStorage<Value>: EncodingStorage where Value: FixedWidthInteger {
    let value: Value

    var header: Header { Value.isSigned ? .signed : .unsigned }
    var payloadSize: Int { value.bitWidth / 8 }

    func optimize(for context: OptimizationContext) { }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) {
        assert(data.count >= payloadSize)

        value.writeFixedWidth(to: data)
    }
}

func signedStorage<T>(value: T) -> EncodingStorage where T: FixedWidthInteger, T: SignedInteger {
    if let value = Int8(exactly: value) {
        return IntegerStorage(value: value)
    }
    if let value = Int16(exactly: value) {
        return IntegerStorage(value: value)
    }
    if let value = Int32(exactly: value) {
        return IntegerStorage(value: value)
    }
    return IntegerStorage(value: value)
}

func unsignedStorage<T>(value: T) -> EncodingStorage where T: FixedWidthInteger, T: UnsignedInteger {
    if let value = UInt8(exactly: value) {
        return IntegerStorage(value: value)
    }
    if let value = UInt16(exactly: value) {
        return IntegerStorage(value: value)
    }
    if let value = UInt32(exactly: value) {
        return IntegerStorage(value: value)
    }
    return IntegerStorage(value: value)
}

struct StringStorage: EncodingStorage {
    private let string: String
    private var index = 0

    var header: Header { .string }
    var payloadSize: Int { index.vsuiSize }

    init(string: String) {
        self.string = string
    }

    mutating func optimize(for context: OptimizationContext) {
        index = context.index(for: string)
    }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) {
        var data = data
        index.write(to: &data)
    }
}
