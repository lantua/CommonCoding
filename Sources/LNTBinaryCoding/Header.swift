//
//  Header.swift
//  
//
//  Created by Natchanon Luangsomboon on 20/2/2563 BE.
//

import Foundation

enum Header {
    case `nil`, string
    case signed, unsigned
    case regularKeyed(RegularKeyedHeader), regularUnkeyed(RegularUnkeyedHeader)
    indirect case equisizeKeyed(EquisizeKeyedHeader), equisizeUnkeyed(EquisizedUnkeyedHeader)
}

extension Header {
    var isNil: Bool {
        guard case .nil = self else {
            return false
        }
        return true
    }
}

struct RegularKeyedHeader {
    var mapping: [(key: Int, size: Int)]

    var totalPayloadSize: Int { mapping.lazy.map { $0.size }.reduce(0, +) }
}

struct EquisizeKeyedHeader {
    var itemSize: Int, subheader: Header?, keys: [Int]

    var payloadSize: Int { itemSize - (subheader?.size ?? 0) }
    var totalPayloadSize: Int { payloadSize * keys.count }
}

struct RegularUnkeyedHeader {
    var sizes: [Int]

    var totalPayloadSize: Int { sizes.reduce(0, +) }
}

struct EquisizedUnkeyedHeader {
    var itemSize: Int, subheader: Header?, count: Int

    var payloadSize: Int { itemSize - (subheader?.size ?? 0) }
    var totalPayloadSize: Int { payloadSize * count }
}

extension Header {
    enum Tag: UInt8 {
        case `nil` = 0x1, signed = 0x2, unsigned = 0x3, string = 0x4
        case regularKeyed = 0x10, equisizeKeyed, uniformKeyed
        case regularUnkeyed = 0x20, equisizeUnkeyed, uniformUnkeyed
    }

    var tag: Tag {
        switch self {
        case .nil: return .nil
        case .signed: return .signed
        case .unsigned: return .unsigned
        case .string: return .string
        case .regularKeyed: return .regularKeyed
        case .regularUnkeyed: return .regularUnkeyed
        case let .equisizeKeyed(header): return header.subheader != nil ? .uniformKeyed : .equisizeKeyed
        case let .equisizeUnkeyed(header): return header.subheader != nil ? .uniformUnkeyed : .equisizeUnkeyed
        }
    }
}
