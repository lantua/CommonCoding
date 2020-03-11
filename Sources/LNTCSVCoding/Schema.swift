//
//  Schema.swift
//  LNTCSVCoding
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

/// Schema of the current object. Contains a single index (for simple types), or key-schema dictionary (for complex types).
enum Schema {
    case value(Int), nested([String: Schema])

    init(data: [(offset: Int, element: Array<Substring>.SubSequence)]) throws {
        // By constrution, `data` can not be empty at non-top level.
        // `data` can not be empty at top-level either as tokenizer
        // always emit at least one element at the beginning.
        assert(!data.isEmpty)

        guard data.allSatisfy({ !$0.element.isEmpty }) else {
            guard data.allSatisfy({ $0.element.isEmpty }) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Mixed multi/single-field entry found"))
            }
            guard data.count == 1 else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Duplicated fields"))
            }
            self = .value(data.first!.offset)
            return
        }
        let groupped = try Dictionary(grouping: data) { String($0.element.first!) }.mapValues {
            try Schema(data: $0.map { ($0.offset, $0.element.dropFirst()) })
        }
        self = .nested(groupped)
    }

    /// Returns `true` if any index in the schema matches `predicate`.
    func contains(where predicate: (Int) throws -> Bool) rethrows -> Bool {
        switch self {
        case let .value(data): return try predicate(data)
        case let .nested(data): return try data.values.contains { try $0.contains(where: predicate) }
        }
    }

    func getKeyedContainer() -> [String: Schema]? {
        guard case let .nested(data) = self else {
            return nil
        }

        return data
    }

    func getUnkeyedContainer() -> [Schema]? {
        guard case let .nested(data) = self else {
            return nil
        }
        var result: [Schema] = []
        for i in 0..<data.count {
            guard let schema = data[String(i)] else {
                break
            }
            result.append(schema)
        }
        return result
    }

    func getValue() -> Int? {
        guard case let .value(value) = self else {
            return nil
        }
        return value
    }
}
