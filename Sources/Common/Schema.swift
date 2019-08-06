//
//  Schema.swift
//  BinaryCoder
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

import Foundation

public indirect enum Schema<Value> {
    case single(Value), keyed([String: Schema])
    /// Unkeyed list of heterogeneous elements
    case unkeyed([Schema])
    /// Indicate that it contains no data
    case noData
}

extension Schema: Codable where Value: Codable {
    enum CodingKeys: CodingKey {
        case single, keyed, unkeyed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keys = container.allKeys

        guard keys.count <= 1 else {
            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "Key must have up to one type, found \(keys.count)"))
        }

        switch keys.first {
        case nil: self = .noData
        case .single?: self = try .single(container.decode(Value.self, forKey: .single))
        case .keyed?: self = try .keyed(container.decode([String: Schema].self, forKey: .keyed))
        case .unkeyed?: self = try .unkeyed(container.decode([Schema].self, forKey: .unkeyed))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .noData: break
        case let .single(value): try container.encode(value, forKey: .single)
        case let .unkeyed(values): try container.encode(values, forKey: .unkeyed)
        case let .keyed(values): try container.encode(values, forKey: .keyed)
        }
    }
}

public extension Schema {
    func contains(where predicate: (Value) throws -> Bool) rethrows -> Bool {
        switch self {
        case .noData: return false
        case let .single(value): return try predicate(value)
        case let .unkeyed(schemas): return try schemas.contains(where: { try $0.contains(where: predicate) })
        case let .keyed(schemas): return try schemas.values.contains(where: { try $0.contains(where: predicate) })
        }
    }
}
