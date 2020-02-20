//
//  Header.swift
//  
//
//  Created by Natchanon Luangsomboon on 20/2/2563 BE.
//

import Foundation

enum Header {
    case `nil`, fixedWidth, stringReference
    case regularKeyed(RegularKeyedHeader), regularUnkeyed(RegularUnkeyedHeader)
    case equisizedKeyed(EquisizedKeyedHeader), equisizedUnkeyed(EquisizedUnkeyedHeader)
    indirect case uniformKeyed(UniformKeyedHeader), uniformUnkeyed(UniformUnkeyedHeader)
}

struct RegularKeyedHeader {
    var mapping: [(key: Int, size: Int)]
}

struct EquisizedKeyedHeader {
    var size: Int, keys: [Int]

    var payloadSize: Int { size * keys.count }
}

struct UniformKeyedHeader {
    var size: Int, subheader: Header, keys: [Int]

    var payloadSize: Int { (size - subheader.size) * keys.count }
}

struct RegularUnkeyedHeader {
    var sizes: [Int]
}

struct EquisizedUnkeyedHeader {
    var size: Int
}

struct UniformUnkeyedHeader {
    var size: Int, subheader: Header, count: Int

    var payloadSize: Int { (size - subheader.size) * count }
}


extension Header {
    enum Tag: UInt8 {
        case `nil` = 0x1
        case fixedWidth = 0x2
        case stringReference = 0x3

        case regularKeyed = 0x10
        case equisizedKeyed
        case uniformKeyed

        case regularUnkeyed = 0x20
        case equisizedUnkeyed
        case uniformUnkeyed

        static var terminator: UInt8 { 0x00 }
    }

    var tag: Tag {
        switch self {
        case .nil: return .nil
        case .fixedWidth: return .fixedWidth
        case .stringReference: return .stringReference
        case .regularKeyed: return .regularKeyed
        case .regularUnkeyed: return .regularUnkeyed
        case .equisizedKeyed: return .equisizedKeyed
        case .equisizedUnkeyed: return .equisizedUnkeyed
        case .uniformKeyed: return .uniformKeyed
        case .uniformUnkeyed: return .uniformUnkeyed
        }
    }
}
