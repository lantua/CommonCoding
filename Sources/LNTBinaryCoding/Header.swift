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
    case equisizeKeyed(EquisizeKeyedHeader), equisizeUnkeyed(EquisizedUnkeyedHeader)
    indirect case uniformKeyed(UniformKeyedHeader), uniformUnkeyed(UniformUnkeyedHeader)
}

struct RegularKeyedHeader {
    var mapping: [(key: Int, size: Int)]

    var totalPayloadSize: Int { mapping.lazy.map { $0.size }.reduce(0, +) }
}

struct EquisizeKeyedHeader {
    var size: Int, keys: [Int]

    var totalPayloadSize: Int { size * keys.count }
}

struct UniformKeyedHeader {
    var itemSize: Int, subheader: Header, keys: [Int]

    var payloadSize: Int { itemSize - subheader.size }
    var totalPayloadSize: Int { (itemSize - subheader.size) * keys.count }
}

struct RegularUnkeyedHeader {
    var sizes: [Int]

    var totalPayloadSize: Int { sizes.reduce(0, +) }
}

struct EquisizedUnkeyedHeader {
    var size: Int, count: Int

    var totalPayloadSize: Int { size * count }
}

struct UniformUnkeyedHeader {
    var itemSize: Int, subheader: Header, count: Int

    var payloadSize: Int { itemSize - subheader.size }
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
        case .equisizeKeyed: return .equisizeKeyed
        case .equisizeUnkeyed: return .equisizeUnkeyed
        case .uniformKeyed: return .uniformKeyed
        case .uniformUnkeyed: return .uniformUnkeyed
        }
    }
}
