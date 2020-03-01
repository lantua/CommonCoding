//
//  PartiallyDecodedStorage.swift
//  
//
//  Created by Natchanon Luangsomboon on 1/3/2563 BE.
//

import Foundation

enum PartiallyParsedStorage {
    case `nil`
    case signed(Int64)
    case unsigned(UInt64)

    case string(String)

    case keyed([String: (Header, Data)])
    case unkeyed([(Header, Data)])
}

extension PartiallyParsedStorage {
    init(_ arg: (header: Header, data: Data), context: DecodingContext) throws {
        var data = arg.data
        switch arg.0 {
        case .nil: self = .nil
        case .signed:
            let value: Int64
            switch data.count {
            case 0: throw BinaryDecodingError.containerTooSmall
            case 1..<2: self = .signed(.init(data.extractFixedWidth(Int8.self)))
            case 2..<4: self = .signed(.init(data.extractFixedWidth(Int16.self)))
            case 4..<8: self = .signed(.init(data.extractFixedWidth(Int32.self)))
            default: self = .signed(.init(data.extractFixedWidth(Int64.self)))
            }
        case .unsigned:
            let value: UInt64
            switch data.count {
            case 0: throw BinaryDecodingError.containerTooSmall
            case 1..<2: self = .unsigned(.init(data.extractFixedWidth(UInt8.self)))
            case 2..<4: self = .unsigned(.init(data.extractFixedWidth(UInt16.self)))
            case 4..<8: self = .unsigned(.init(data.extractFixedWidth(UInt32.self)))
            default: self = .unsigned(.init(data.extractFixedWidth(UInt64.self)))
            }
        case .string:
            var data = data
            self = try .string(context.string(at: data.extractVSUI()))
        case let .regularKeyed(header):
            guard header.totalPayloadSize <= data.count else {
                throw BinaryDecodingError.containerTooSmall
            }

            var data = data
            self = try .keyed(.init(header.mapping.lazy.map { arg in
                let key = try context.string(at: arg.key)
                defer { data.removeFirst(arg.size) }
                return try (key, data.prefix(arg.size).splitHeader())
            }) { $1 })
        case let .equisizeKeyed(header):
            guard header.totalPayloadSize <= data.count else {
                throw BinaryDecodingError.containerTooSmall
            }
            
            let size = header.size
            var data = data
            
            self = try .keyed(.init(header.keys.lazy.map { keyIndex in
                let key = try context.string(at: keyIndex)
                defer { data.removeFirst(size) }
                let (header, payload) = try data.prefix(size).splitHeader()
                return (key, (header, payload))
            }) { $1 })
        case let .uniformKeyed(header):
            guard header.totalPayloadSize <= data.count else {
                throw BinaryDecodingError.containerTooSmall
            }
            
            let subheader = header.subheader
            let payloadSize = header.payloadSize
            var data = data
            
            self = try .keyed(.init(header.keys.lazy.map { keyIndex in
                let key = try context.string(at: keyIndex)
                defer { data.removeFirst(payloadSize) }
                return (key, (subheader, data.prefix(payloadSize)))
            }) { $1 })
        case let .regularUnkeyed(header):
            guard header.totalPayloadSize <= data.count else {
                throw BinaryDecodingError.containerTooSmall
            }
            
            var data = data
            self = try .unkeyed(header.sizes.map { size in
                defer { data.removeFirst(size) }
                return try data.prefix(size).splitHeader()
            })
        case let .equisizeUnkeyed(header):
            guard header.totalPayloadSize <= data.count else {
                throw BinaryDecodingError.containerTooSmall
            }
            
            var data = data
            let size = header.size
            self = try .unkeyed((0..<header.count).map { _ in
                defer { data.removeFirst(size) }
                return try data.prefix(size).splitHeader()
            })
        case let .uniformUnkeyed(header):
            guard header.totalPayloadSize <= data.count else {
                throw BinaryDecodingError.containerTooSmall
            }
            
            var data = data
            let subheader = header.subheader
            let payloadSize = header.payloadSize
            self = .unkeyed((0..<header.count).map { _ in
                defer { data.removeFirst(payloadSize) }
                return (subheader, data.prefix(payloadSize))
            })
        }
    }
}

extension PartiallyParsedStorage {
    var isNil: Bool {
        guard case .nil = self else {
            return false
        }
        return true
    }
}
