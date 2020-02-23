//
//  InternalDecoder.swift
//  LNTBinaryCoding
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

import Foundation

typealias HeaderData = (header: Header, data: Data)

private enum ContainerType {
    case singleValue(SingleValueDecodingContainer)
    case unkeyed(UnkeyedDecodingContainer)
    case stringKeyed(StringKeyedDecodingContainer)
}

struct InternalDecoder: Decoder {
    private let container: ContainerType, context: DecodingContext

    init(container: SingleValueDecodingContainer, context: DecodingContext) {
        self.container = .singleValue(container)
        self.context = context
    }

    var userInfo: [CodingUserInfoKey : Any] { context.userInfo }
    var codingPath: [CodingKey] { context.codingPath }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        guard case let .stringKeyed(container) = container else {
            throw DecodingError.typeMismatch(KeyedDecodingContainer<Key>.self, context.error("Requesting from an incompatible container"))
        }

        return .init(KeyedBinaryDecodingContainer(container: container))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case let .unkeyed(container) = container else {
            throw DecodingError.typeMismatch(UnkeyedDecodingContainer.self, context.error("Requesting from an incompatible container"))
        }

        return container
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        guard case let .singleValue(container) = container else {
            throw DecodingError.typeMismatch(SingleValueDecodingContainer.self, context.error("Requesting from an incompatible container"))
        }

        return container
    }
}

extension InternalDecoder {
    init(parsed: HeaderData, context: DecodingContext) throws {
        self.context = context

        do {
            let (header, data) = parsed
            switch header {
            case .nil: container = .singleValue(NilDecodingContainer(context: context))
            case .signed: container = try .singleValue(signedDecodingContainer(data: data, context: context))
            case .unsigned: container = try .singleValue(unsignedDecodingContainer(data: data, context: context))
            case .string: container = .singleValue(StringDecodingContainer(data: data, context: context))
            case let .regularKeyed(header): container = try .stringKeyed(.init(header: header, data: data, context: context))
            case let .equisizeKeyed(header): container = try .stringKeyed(.init(header: header, data: data, context: context))
            case let .uniformKeyed(header): container = try .stringKeyed(.init(header: header, data: data, context: context))
            case let .regularUnkeyed(header): self.container = try .unkeyed(UnkeyedBinaryDecodingContainer(header: header, data: data, context: context))
            case let .equisizeUnkeyed(header): self.container = try .unkeyed(UnkeyedBinaryDecodingContainer(header: header, data: data, context: context))
            case let .uniformUnkeyed(header): self.container = try .unkeyed(UnkeyedBinaryDecodingContainer(header: header, data: data, context: context))
            }
        } catch {
            throw DecodingError.dataCorrupted(context.error(error: error))
        }
    }
}
