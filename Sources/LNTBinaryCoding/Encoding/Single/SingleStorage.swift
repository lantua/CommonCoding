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

        if Value.isSigned {
            switch data.count {
            case 1..<2: Int8(value).littleEndian.writeFixedWidth(to: data)
            case 2..<4: Int16(value).littleEndian.writeFixedWidth(to: data)
            case 4..<8: Int32(value).littleEndian.writeFixedWidth(to: data)
            default: Int64(value).littleEndian.writeFixedWidth(to: data)
            }
        } else {
            switch data.count {
            case 1..<2: UInt8(value).littleEndian.writeFixedWidth(to: data)
            case 2..<4: UInt16(value).littleEndian.writeFixedWidth(to: data)
            case 4..<8: UInt32(value).littleEndian.writeFixedWidth(to: data)
            default: UInt64(value).littleEndian.writeFixedWidth(to: data)
            }
        }
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
