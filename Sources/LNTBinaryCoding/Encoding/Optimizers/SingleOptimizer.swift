//
//  SingleOptimizer.swift
//  
//
//  Created by Natchanon Luangsomboon on 20/2/2563 BE.
//

import Foundation

struct NilOptimizer: EncodingOptimizer {
    var header: Header { .nil }
    var payloadSize: Int { 0 }

    func optimize(for context: OptimizationContext) { }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) { }
}

struct SignedOptimizer: EncodingOptimizer {
    let value: Int64

    var header: Header { .signed }
    var payloadSize: Int

    init<T>(value: T) where T: FixedWidthInteger, T: SignedInteger {
        self.value = Int64(value)
        switch T.bitWidth - max(value.leadingZeroBitCount, (~value).leadingZeroBitCount) {
        case 0..<8: payloadSize = 1
        case 8..<16: payloadSize = 2
        case 16..<32: payloadSize = 4
        default: payloadSize = 8
        }
    }

    func optimize(for context: OptimizationContext) { }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) {
        switch data.count {
        case 1..<2: Int8(value).littleEndian.writeFixedWidth(to: data)
        case 2..<4: Int16(value).littleEndian.writeFixedWidth(to: data)
        case 4..<8: Int32(value).littleEndian.writeFixedWidth(to: data)
        default: Int64(value).littleEndian.writeFixedWidth(to: data)
        }
    }
}

struct UnsignedOptimizer: EncodingOptimizer {
    let value: UInt64

    var header: Header { .unsigned }
    var payloadSize: Int

    init<T>(value: T) where T: FixedWidthInteger, T: UnsignedInteger {
        self.value = UInt64(value)
        switch T.bitWidth - value.leadingZeroBitCount {
        case 0..<8: payloadSize = 1
        case 8..<16: payloadSize = 2
        case 16..<32: payloadSize = 4
        default: payloadSize = 8
        }
    }

    func optimize(for context: OptimizationContext) { }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) {
        switch data.count {
        case 1..<2: UInt8(value).littleEndian.writeFixedWidth(to: data)
        case 2..<4: UInt16(value).littleEndian.writeFixedWidth(to: data)
        case 4..<8: UInt32(value).littleEndian.writeFixedWidth(to: data)
        default: UInt64(value).littleEndian.writeFixedWidth(to: data)
        }
    }
}

struct StringStorage: EncodingOptimizer {
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
