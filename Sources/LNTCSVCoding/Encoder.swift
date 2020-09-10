//
//  Encoder.swift
//  LNTCSVCoding
//
//  Created by Natchanon Luangsomboon on 31/7/2562 BE.
//

import LNTSharedCoding

// MARK: Context

/// Encoding context, shared between all internal encoders, containers, etc. during single-element encoding process.
class SharedEncodingContext {
    let isFixed: Bool, subheaderSeparator: String
    var fieldIndices: [String: Int], values: [String??]

    init(encoder: CSVEncoder, fieldIndices: [String: Int]? = nil) {
        self.fieldIndices = fieldIndices ?? [:]
        self.subheaderSeparator = .init(encoder.subheaderSeparator)
        
        isFixed = fieldIndices != nil
        values = Array(repeating: nil, count: (fieldIndices?.count ?? 0))
    }

    func finalize() -> (fieldIndices: [String: Int], values: [String?]) {
        (fieldIndices, values.map { $0 as? String })
    }
}

extension CodingContext where Shared == SharedEncodingContext {
    func add(unescaped: String?) throws {
        let field = fieldName
        if shared.isFixed {
            guard let index = shared.fieldIndices[field] else {
                guard unescaped != nil else {
                    // It's fine to add `nil` to non-existing field
                    return
                }
                throw EncodingError.invalidValue(unescaped as Any, error("Key does not match any header fields"))
            }
            if let oldValue = shared.values[index] {
                guard oldValue != unescaped else {
                    // It's fine to add same value to duplicated field
                    return
                }
                throw EncodingError.invalidValue(unescaped as Any, error("Duplicated field"))
            }

            shared.values[index] = unescaped
        } else {
            if let oldIndex = shared.fieldIndices.updateValue(shared.values.count, forKey: field) {
                guard shared.values[oldIndex]! != unescaped else {
                    // It's fine to add same value to duplicated field
                    shared.fieldIndices.updateValue(oldIndex, forKey: field)
                    return
                }
                throw EncodingError.invalidValue(unescaped as Any, error("Duplicated field"))
            }
            shared.values.append(unescaped)
        }
    }

    private var fieldName: String {
        path.expanded.map { $0.stringValue }.joined(separator: shared.subheaderSeparator)
    }
}

// MARK: Encoder

/// Internal decoder. This is what the `Decodable` uses when decoding
struct CSVInternalEncoder: ContextContainer, Encoder {
    let context: CodingContext<SharedEncodingContext>

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        .init(CSVKeyedEncodingContainer(context: context))
    }
    func unkeyedContainer() -> UnkeyedEncodingContainer { CSVUnkeyedEncodingContainer(context: context) }
    func singleValueContainer() -> SingleValueEncodingContainer { self }
}

// MARK: Keyed Container

private struct CSVKeyedEncodingContainer<Key: CodingKey>: ContextContainer, KeyedEncodingContainerProtocol {
    let context: CodingContext<SharedEncodingContext>

    private func encoder(forKey key: CodingKey) -> CSVInternalEncoder {
        .init(context: context.appending(key))
    }

    mutating func encodeNil(forKey key: Key) throws { try context.appending(key).add(unescaped: nil) }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable, T: LosslessStringConvertible {
        try context.appending(key).add(unescaped: String(value))
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable { try value.encode(to: encoder(forKey: key)) }
    mutating func superEncoder() -> Encoder { encoder(forKey: SuperCodingKey()) }
    mutating func superEncoder(forKey key: Key) -> Encoder { encoder(forKey: key) }
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer { encoder(forKey: key).unkeyedContainer() }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        encoder(forKey: key).container(keyedBy: NestedKey.self)
    }

    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init(_:)), forKey: key) }
    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init(_:)), forKey: key) }
    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws {
        try value != nil ? encode(value!, forKey: key) : encodeNil(forKey: key)
    }
}

// MARK: Unkeyed Container

private struct CSVUnkeyedEncodingContainer: ContextContainer, UnkeyedEncodingContainer {
    var count = 0

    let context: CodingContext<SharedEncodingContext>

    private mutating func consumeContext() -> CodingContext<SharedEncodingContext> {
        defer { count += 1 }
        return context.appending(UnkeyedCodingKey(intValue: count))
    }
    private mutating func consumeEncoder() -> CSVInternalEncoder {
        .init(context: consumeContext())
    }
    
    mutating func encodeNil() throws { try consumeContext().add(unescaped: nil) }

    mutating func encode<T>(_ value: T) throws where T: Encodable, T: LosslessStringConvertible {
        try consumeContext().add(unescaped: String(value))
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable { try value.encode(to: consumeEncoder()) }
    mutating func superEncoder() -> Encoder { consumeEncoder() }
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer { consumeEncoder().unkeyedContainer() }
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        .init(CSVKeyedEncodingContainer(context: consumeContext()))
    }
}

// MARK: Single Value Container

extension CSVInternalEncoder: SingleValueEncodingContainer {
    mutating func encodeNil() throws { try context.add(unescaped: nil) }

    mutating func encode<T>(_ value: T) throws where T: Encodable { try value.encode(to: self) }
    mutating func encode<T>(_ value: T) throws where T: Encodable, T: LosslessStringConvertible {
        try context.add(unescaped: String(value))
    }
}
