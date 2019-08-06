//
//  Schema.swift
//  BinaryCoder
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

import Foundation

public final class Schema<Value> {
    enum Raw {
        case empty, value(Value), keyed([String: Schema]), unkeyed([Schema])
    }

    let data: Raw
    private var keyedCache: [ObjectIdentifier: [String: Schema]] = [:], unkeyedCache: [Schema]? = nil

    public init() { data = .empty }
    public init(value: Value) { data = .value(value) }
    public init(unkeyed: [Schema]) { data = .unkeyed(unkeyed) }
    public init(keyed: [String: Schema]) { data = .keyed(keyed) }

    public func clearCache() {
        keyedCache = [:]
        unkeyedCache = nil

        switch data {
        case .value, .empty: break
        case let .keyed(data):
            data.values.forEach { $0.clearCache() }
        case let .unkeyed(data):
            data.forEach { $0.clearCache() }
        }
    }

    public func contains(where predicate: (Value) throws -> Bool) rethrows -> Bool {
        switch data {
        case .empty: return false
        case let .value(data): return try predicate(data)
        case let .keyed(data): return try data.values.contains { try $0.contains(where: predicate) }
        case let .unkeyed(data): return try data.contains { try $0.contains(where: predicate) }
        }
    }
}

public extension Schema {
    func getContainer<Key: CodingKey>(keyedBy keys: Key.Type) -> [String: Schema]? {
        let identifier = ObjectIdentifier(keys.self)
        guard let cache = keyedCache[identifier] else {
            let result: [String: Schema]
            switch data {
            case let .keyed(data):
                // "super" key is the special key for superEncoder/Decoder functions
                result = data.filter { Key(stringValue: $0.key) != nil || $0.key == "super" }
            case let .unkeyed(data):
                result = Dictionary(uniqueKeysWithValues: data.enumerated().compactMap { arg in Key(intValue: arg.offset).map { ($0.stringValue, arg.element) } })
            case .value, .empty: return nil
            }
            keyedCache[identifier] = result
            return result
        }
        return cache
    }

    func getUnkeyedContainer() -> [Schema]? {
        guard let cache = unkeyedCache else {
            let result: [Schema]
            switch data {
            case let .keyed(data):
                if let last = data.keys.compactMap(Int.init).max(),
                    last >= 0 {
                    result = (0...last).map { data[String($0)] ?? .init() }
                } else {
                    result = []
                }
            case let .unkeyed(data): result = data
            case .value, .empty: return nil
            }
            unkeyedCache = result
            return result
        }
        return cache
    }

    func getValue() -> Value? {
        guard case let .value(value) = data else {
            return nil
        }
        return value
    }
}

extension Schema: ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public convenience init(dictionaryLiteral elements: (String, Schema)...) {
        self.init(keyed: .init(uniqueKeysWithValues: elements))
    }

    public convenience init(arrayLiteral elements: Schema...) {
        self.init(unkeyed: elements)
    }
}

extension Schema: Codable where Value: Codable {
    enum CodingKeys: CodingKey {
        case value, keyed, unkeyed
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keys = container.allKeys

        guard keys.count <= 1 else {
            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "Key must have up to one type, found \(keys.count)"))
        }

        switch keys.first {
        case nil: self.init()
        case .value?: try self.init(value: container.decode(Value.self, forKey: .value))
        case .keyed?: try self.init(keyed: container.decode([String: Schema].self, forKey: .keyed))
        case .unkeyed?: try self.init(unkeyed: container.decode([Schema].self, forKey: .unkeyed))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch data {
        case .empty: break
        case let .value(value): try container.encode(value, forKey: .value)
        case let .unkeyed(values): try container.encode(values, forKey: .unkeyed)
        case let .keyed(values): try container.encode(values, forKey: .keyed)
        }
    }
}
