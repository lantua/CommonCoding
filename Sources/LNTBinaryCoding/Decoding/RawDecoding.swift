//
//  RawDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 20/2/2563 BE.
//

import Foundation

extension Data {
    mutating func extractVSUI() throws -> Int {
        var result = 0, first = 0 as UInt8
        repeat {
            guard !isEmpty,
                result.leadingZeroBitCount > 7 else {
                    throw BinaryDecodingError.invalidVSUI
            }

            first = removeFirst()
            result <<= 7
            result |= Int(first) & (1<<7 - 1)
        } while first & 1<<7 != 0

        return result
    }

    mutating func extractString() throws -> String {
        guard let terminatorIndex = firstIndex(where: { $0 == 0 }),
            let string = String(data: self[startIndex..<terminatorIndex], encoding: .utf8) else {
                throw BinaryDecodingError.invalidString
        }

        removeSubrange(...terminatorIndex)
        return string
    }

    mutating func extractHeader() throws -> Header {
        guard !isEmpty else {
            return .nil
        }

        let rawTag = removeFirst()
        guard let tag = Header.Tag(rawValue: rawTag) else {
            throw BinaryDecodingError.invalidTag
        }

        switch tag {
        case .nil: return .nil
        case .signed: return .signed
        case .unsigned: return .unsigned
        case .string: return .string
        case .regularKeyed: return try .regularKeyed(extractRegularKeyedHeader())
        case .equisizeKeyed: return try .equisizeKeyed(extractEquisizedKeyedHeader())
        case .uniformKeyed: return try .uniformKeyed(extractUniformKeyedHeader())
        case .regularUnkeyed: return try .regularUnkeyed(extractRegularUnkeyedHeader())
        case .equisizeUnkeyed: return try .equisizeUnkeyed(extractEquisizedUnkeyedHeader())
        case .uniformUnkeyed: return try .uniformUnkeyed(extractUniformUnkeyedHeader())
        }
    }
}

private extension Data {
    mutating func extractRegularKeyedHeader() throws -> RegularKeyedHeader {
        var mapping: [(key: Int, size: Int)] = []
        var size = try extractVSUI()
        while size != 1 {
            let key = try extractVSUI()
            mapping.append((key, size))
            size = try extractVSUI()
        }

        return .init(mapping: mapping)
    }

    mutating func extractEquisizedKeyedHeader() throws -> EquisizeKeyedHeader {
        var keys: [Int] = []

        let size = try extractVSUI()
        var keyIndex = try extractVSUI()
        while keyIndex != 0 {
            keys.append(keyIndex)
            keyIndex = try extractVSUI()
        }

        return .init(size: size, keys: keys)
    }

    mutating func extractUniformKeyedHeader() throws -> UniformKeyedHeader {
        let itemSize = try extractVSUI()
        var keys: [Int] = []
        var keyIndex = try extractVSUI()
        while keyIndex != 0 {
            keys.append(keyIndex)
            keyIndex = try extractVSUI()
        }

        let header = try extractHeader()

        return .init(itemSize: itemSize, subheader: header, keys: keys)
    }

    mutating func extractRegularUnkeyedHeader() throws -> RegularUnkeyedHeader {
        var sizes: [Int] = []
        var size = try extractVSUI()
        while size != 1 {
            sizes.append(size)
            size = try extractVSUI()
        }

        return .init(sizes: sizes)
    }

    mutating func extractEquisizedUnkeyedHeader() throws -> EquisizedUnkeyedHeader {
        let size = try extractVSUI()
        let count = try extractVSUI()
        return .init(size: size, count: count)
    }

    mutating func extractUniformUnkeyedHeader() throws -> UniformUnkeyedHeader {
        let itemSize = try extractVSUI()
        let count  = try extractVSUI()
        let subheader = try extractHeader()
        return .init(itemSize: itemSize, subheader: subheader, count: count)
    }
}

extension Data {
    private func readFixed<T>(_: T.Type) -> T where T: FixedWidthInteger {
        var result: T = 0
        Swift.withUnsafeMutableBytes(of: &result) { raw in
            raw.copyBytes(from: prefix(T.bitWidth / 8))
        }
        return .init(littleEndian: result)
    }
    func readSigned<T>(_: T.Type) -> T? where T: FixedWidthInteger {
        switch count {
        case 0: return 0
        case 1..<2: return T(exactly: readFixed(Int8.self))
        case 2..<4: return T(exactly: readFixed(Int16.self))
        case 4..<8: return T(exactly: readFixed(Int32.self))
        default: return T(exactly: readFixed(Int64.self))
        }
    }
    func readUnsigned<T>(_: T.Type) -> T? where T: FixedWidthInteger {
        switch count {
        case 0: return 0
        case 1..<2: return T(exactly: readFixed(UInt8.self))
        case 2..<4: return T(exactly: readFixed(UInt16.self))
        case 4..<8: return T(exactly: readFixed(UInt32.self))
        default: return T(exactly: readFixed(UInt64.self))
        }
    }

    func readVSUI() throws -> Int {
        var tmp = self
        return try tmp.extractVSUI()
    }
}
