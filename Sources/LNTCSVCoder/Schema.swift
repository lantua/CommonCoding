//
//  Schema.swift
//  LNTCSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

final class Schema {
    enum Raw {
        case value(Int), nested([String: Schema])
    }
    let raw: Raw

    var keyedCache: [ObjectIdentifier: [String: Schema]] = [:], unkeyedCache: [Schema]?

    init<A>(data: [(path: A, index: Int)]) throws where A: Collection, A.Element: StringProtocol {
        // By constrution, `data` can not be empty at non-top level.
        // `data` can not be empty at top-level either as tokenizer
        // always emit at least one element at the beginning.
        assert(!data.isEmpty)

        guard data.allSatisfy({ !$0.path.isEmpty }) else {
            if data.contains(where: { !$0.path.isEmpty }) {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Mixed multi/single-field entry found"))
            }
            if data.count > 1 {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Duplicated fields"))
            }
            raw = .value(data.first!.index)
            return
        }
        let groupped: [String: Schema] = try Dictionary(grouping: data) { String($0.path.first!) }.mapValues {
            try Schema(data: $0.map { ($0.path.dropFirst(), $0.index) })
        }
        raw = .nested(groupped)
    }

    func contains(where predicate: (Int) throws -> Bool) rethrows -> Bool {
        switch raw {
        case let .value(data): return try predicate(data)
        case let .nested(data): return try data.values.contains { try $0.contains(where: predicate) }
        }
    }

    func getContainer<Key: CodingKey>(keyedBy keys: Key.Type) -> [String: Schema]? {
        let identifier = ObjectIdentifier(keys.self)
        guard let cache = keyedCache[identifier] else {
            guard case let .nested(data) = raw else {
                return nil
            }
            // "super" key is a special key for superEncoder/Decoder functions
            let result = data.filter { Key(stringValue: $0.key) != nil || $0.key == "super" }
            keyedCache[identifier] = result
            return result
        }
        return cache
    }

    func getUnkeyedContainer() -> [Schema]? {
        guard let cache = unkeyedCache else {
            guard case let .nested(data) = raw else {
                return nil
            }
            var result: [Schema] = []
            for i in 0..<data.count {
                guard let schema = data[String(i)] else {
                    break
                }
                result.append(schema)
            }

            unkeyedCache = result
            return result
        }
        return cache
    }

    func getValue() -> Int? {
        guard case let .value(value) = raw else {
            return nil
        }
        return value
    }
}
