//
//  RawDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 20/2/2563 BE.
//

import Foundation

extension Header {
    /// Extract header from data, and remove the header portion.
    init(data: inout Data) throws {
        guard !data.isEmpty else {
            self = .nil
            return
        }

        let rawTag = data.removeFirst()
        guard let tag = Header.Tag(rawValue: rawTag) else {
            throw BinaryDecodingError.invalidTag
        }

        switch tag {
        case .nil: self = .nil
        case .signed: self = .signed
        case .unsigned: self = .unsigned
        case .string: self = .string
        case .regularKeyed: self = try .regularKeyed(.init(data: &data))
        case .equisizeKeyed: self = try .equisizeKeyed(.init(data: &data))
        case .uniformKeyed: self = try .uniformKeyed(.init(data: &data))
        case .regularUnkeyed: self = try .regularUnkeyed(.init(data: &data))
        case .equisizeUnkeyed: self = try .equisizeUnkeyed(.init(data: &data))
        case .uniformUnkeyed: self = try .uniformUnkeyed(.init(data: &data))
        }
    }
}

extension Data {
    /// Read VSUI value from the data, and remove the read portion.
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

    func extractFixedWidth<T>(_: T.Type) -> T where T: FixedWidthInteger {
        assert(count >= T.bitWidth / 8)

        var result: T = 0
        Swift.withUnsafeMutableBytes(of: &result) { raw in
            raw.copyBytes(from: prefix(T.bitWidth / 8))
        }
        return .init(littleEndian: result)
    }

    /// Read null-terminated utf8 string from the data, and remove the read portion.
    mutating func readString() throws -> String {
        guard let terminatorIndex = firstIndex(where: { $0 == 0 }),
            let string = String(data: self[startIndex..<terminatorIndex], encoding: .utf8) else {
                throw BinaryDecodingError.invalidString
        }

        removeSubrange(...terminatorIndex)
        return string
    }

    /// Returns header and data portion.
    func splitHeader() throws -> (Header, Data) {
        var temp = self
        let header = try Header(data: &temp)
        return (header, temp)
    }
}
