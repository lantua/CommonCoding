//
//  RawDecoding.swift
//  
//
//  Created by Natchanon Luangsomboon on 20/2/2563 BE.
//

import Foundation

extension Data {
    subscript(offset range: Range<Int>) -> Data {
        assert(count >= range.upperBound)
        let lower = index(startIndex, offsetBy: range.lowerBound)
        let upper = index(startIndex, offsetBy: range.upperBound)
        return self[lower..<upper]
    }
}

extension Header {
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
        case .fixedWidth: self = .fixedWidth
        case .stringReference: self = .stringReference
        case .regularKeyed: self = try .regularKeyed(.init(data: &data))
        case .equisizedKeyed: self = try .equisizedKeyed(.init(data: &data))
        case .uniformKeyed: self = try .uniformKeyed(.init(data: &data))
        case .regularUnkeyed: self = try .regularUnkeyed(.init(data: &data))
        case .equisizedUnkeyed: self = try .equisizedUnkeyed(.init(data: &data))
        case .uniformUnkeyed: self = try .uniformUnkeyed(.init(data: &data))
        }
    }
}

extension Data {
    mutating func readInteger() throws -> Int {
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

    mutating func readString() throws -> String {
        guard let terminatorIndex = firstIndex(where: { $0 == 0 }),
            let string = String(data: self[startIndex..<terminatorIndex], encoding: .utf8) else {
                throw BinaryDecodingError.invalidString
        }

        removeSubrange(...terminatorIndex)
        return string
    }

    func splitHeader() throws -> HeaderData {
        var temp = self
        let header = try Header(data: &temp)
        return (header, temp)
    }
}
