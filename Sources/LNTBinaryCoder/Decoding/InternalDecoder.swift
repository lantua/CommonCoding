//
//  InternalDecoder.swift
//  LNTBinaryCoder
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

import Foundation

typealias HeaderData = (header: Header, data: Data)

struct InternalDecoder: Decoder {
    let header: Header, data: Data, context: DecodingContext

    init(parsed: HeaderData, context: DecodingContext) {
        (header, data) = parsed
        self.context = context
    }

    var userInfo: [CodingUserInfoKey : Any] { context.userInfo }
    var codingPath: [CodingKey] { context.codingPath }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        do {
            switch header {
            case let .regularKeyed(header): return try .init(NonUniformKeyedDecodingContainer(header: header, data: data, context: context))
            case let .equisizeKeyed(header): return try .init(NonUniformKeyedDecodingContainer(header: header, data: data, context: context))
            case let .uniformKeyed(header): return try .init(UniformKeyedDecodingContainer(header: header, data: data, context: context))
            default: break
            }
        } catch {
            throw DecodingError.dataCorrupted(context.error(error: error))
        }
        throw DecodingError.typeMismatch(KeyedDecodingContainer<Key>.self, context.error("Requesting from a \(header.tag) block"))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        do {
            switch header {
            case let .regularUnkeyed(header): return try RegularUnkeyedDecodingContainer(header: header, data: data, context: context)
            case let .equisizeUnkeyed(header): return EquisizedUnkeyedDecodingContainer(header: header, data: data, context: context)
            case let .uniformUnkeyed(header): return try UniformUnkeyedDecodingContainer(header: header, data: data, context: context)

            default: break
            }
        } catch {
            throw DecodingError.dataCorrupted(context.error(error: error))
        }
        throw DecodingError.typeMismatch(UnkeyedDecodingContainer.self, context.error("Requesting from a \(header.tag) block"))
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        switch header {
        case .fixedWidth: return FixedWidthDecodingContainer(data: data, context: context)
        case .nil: return NilDecodingContainer(context: context)
        case .stringReference: return StringDecodingContainer(data: data, context: context)

        default:
            throw DecodingError.typeMismatch(SingleValueDecodingContainer.self, context.error("Requesting from a \(header.tag) block"))
        }
    }
}
