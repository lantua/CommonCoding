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

extension Storage {
    func parse(context: DecodingContext) throws -> Storage {
        guard case let .unparsed(header, data) = self else {
            return self
        }

        switch header {
        case .nil: return .nil
        case .signed:
            let value: Int64
            switch data.count {
            case 0: throw BinaryDecodingError.containerTooSmall
            case 1..<2: value = .init(data.extractFixedWidth(Int8.self))
            case 2..<4: value = .init(data.extractFixedWidth(Int16.self))
            case 4..<8: value = .init(data.extractFixedWidth(Int32.self))
            default: value = .init(data.extractFixedWidth(Int64.self))
            }
            return .signed(value)
        case .unsigned:
            let value: UInt64
            switch data.count {
            case 0: throw BinaryDecodingError.containerTooSmall
            case 1..<2: value = .init(data.extractFixedWidth(UInt8.self))
            case 2..<4: value = .init(data.extractFixedWidth(UInt16.self))
            case 4..<8: value = .init(data.extractFixedWidth(UInt32.self))
            default: value = .init(data.extractFixedWidth(UInt64.self))
            }
            return .unsigned(value)
        case .string:
            var data = data
            return try .string(context.string(at: data.extractVSUI()))
        case let .regularKeyed(header):
            guard header.totalPayloadSize <= data.count else {
                throw BinaryDecodingError.containerTooSmall
            }

            var data = data
            return try .keyed(.init(header.mapping.lazy.map { arg in
                let key = try context.string(at: arg.key)
                defer { data.removeFirst(arg.size) }
                let (header, payload) = try data.prefix(arg.size).splitHeader()
                return (key, .unparsed(header, payload))
            }) { $1 })
        case let .equisizeKeyed(header):
            guard header.totalPayloadSize <= data.count else {
                throw BinaryDecodingError.containerTooSmall
            }

            let size = header.size
            var data = data

            return try .keyed(.init(header.keys.lazy.map { keyIndex in
                let key = try context.string(at: keyIndex)
                defer { data.removeFirst(size) }
                let (header, payload) = try data.prefix(size).splitHeader()
                return (key, .unparsed(header, payload))
            }) { $1 })
        case let .uniformKeyed(header):
            guard header.totalPayloadSize <= data.count else {
                throw BinaryDecodingError.containerTooSmall
            }

            let subheader = header.subheader
            let payloadSize = header.payloadSize
            var data = data

            return try .keyed(.init(header.keys.lazy.map { keyIndex in
                let key = try context.string(at: keyIndex)
                defer { data.removeFirst(payloadSize) }
                let payload = data.prefix(payloadSize)
                return (key, .unparsed(subheader, payload))
            }) { $1 })
        case let .regularUnkeyed(header):
            guard header.totalPayloadSize <= data.count else {
                throw BinaryDecodingError.containerTooSmall
            }

            var data = data
            return try .unkeyed(header.sizes.map { size in
                let (header, payload) = try data.prefix(size).splitHeader()
                defer { data.removeFirst(size) }
                return .unparsed(header, payload)
            })
        case let .equisizeUnkeyed(header):
            guard header.totalPayloadSize <= data.count else {
                throw BinaryDecodingError.containerTooSmall
            }

            var data = data
            let size = header.size
            return try .unkeyed((0..<header.count).map { _ in
                let (header, payload) = try data.prefix(size).splitHeader()
                defer { data.removeFirst(size) }
                return .unparsed(header, payload)
            })
        case let .uniformUnkeyed(header):
            guard header.totalPayloadSize <= data.count else {
                throw BinaryDecodingError.containerTooSmall
            }

            var data = data
            let subheader = header.subheader
            let payloadSize = header.payloadSize
            return .unkeyed((0..<header.count).map { _ in
                let payload = data.prefix(payloadSize)
                defer { data.removeFirst(payloadSize) }
                return .unparsed(subheader, payload)
            })
        }
    }
}
