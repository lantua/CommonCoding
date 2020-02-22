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

struct SignedStorage: EncodingStorage {
    let raw: Data

    var header: Header { .signed }
    var payloadSize: Int { raw.count }

    init<T>(value: T) where T: FixedWidthInteger, T: SignedInteger {
        let isNegative = value < 0, end = isNegative ? -1 : 0
        var value = value, raw = Data()
        var canEnd: Bool

        repeat {
            canEnd = (value & 0x80 != 0) == isNegative
            raw.append(UInt8(value & 0xff))
            value >>= 8
        } while value != end || !canEnd
        self.raw = raw
    }

    func optimize(for context: OptimizationContext) { }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) {
        assert(data.count >= raw.count)

        let sign = data.last! & 0x80 != 0

        raw.copyBytes(to: UnsafeMutableRawBufferPointer(rebasing: data))

        let unused = data.prefix(16).dropFirst(raw.count)
        UnsafeMutableRawBufferPointer(rebasing: unused)
            .copyBytes(from: repeatElement(sign ? 0xff : 0x00, count: unused.count))
    }
}

struct UnsignedStorage: EncodingStorage {
    let raw: Data

    var header: Header { .unsigned }
    var payloadSize: Int { raw.count }

    init<T>(value: T) where T: FixedWidthInteger, T: UnsignedInteger {
        var value = value, raw = Data()

        repeat {
            raw.append(UInt8(value & 0xff))
            value >>= 8
        } while value != 0
        self.raw = raw
    }

    func optimize(for context: OptimizationContext) { }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) {
        assert(data.count >= raw.count)

        raw.copyBytes(to: UnsafeMutableRawBufferPointer(rebasing: data))

        let unused = data.prefix(16).dropFirst(raw.count)
        UnsafeMutableRawBufferPointer(rebasing: unused)
            .copyBytes(from: repeatElement(0, count: unused.count))
    }
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
