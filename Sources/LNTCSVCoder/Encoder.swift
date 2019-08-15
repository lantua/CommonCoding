//
//  Encoder.swift
//  LNTCSVCoder
//
//  Created by Natchanon Luangsomboon on 31/7/2562 BE.
//

class EncodingContext {
    private let encoder: CSVEncoder, isFixed: Bool
    private var fieldIndices: [String: Int], values: [String??]

    var userInfo: [CodingUserInfoKey: Any] { return encoder.userInfo }

    init(encoder: CSVEncoder, fieldIndices: [String: Int]? = nil) {
        self.encoder = encoder
        self.fieldIndices = fieldIndices ?? [:]
        
        isFixed = fieldIndices != nil
        values = Array(repeating: nil, count: (fieldIndices?.count ?? 0))
    }
    
    func add(unescaped: String?, to codingPath: [CodingKey]) throws {
        if isFixed {
            guard let index = fieldIndices[encoder.field(for: codingPath)] else {
                guard unescaped != nil else {
                    // It's fine to add `nil` to non-existing field
                    return
                }
                throw EncodingError.invalidValue(unescaped as Any, .init(codingPath: codingPath, debugDescription: "Key does not match any header fields"))
            }
            if let oldValue = values[index] {
                guard oldValue != unescaped else {
                    // It's fine to add same value to duplicated field
                    return
                }
                throw EncodingError.invalidValue(unescaped as Any, .init(codingPath: codingPath, debugDescription: "Duplicated field"))
            }
            
            values[index] = unescaped
        } else {
            if let oldIndex = fieldIndices.updateValue(values.count, forKey: encoder.field(for: codingPath)) {
                guard values[oldIndex]! != unescaped else {
                    // It's fine to add same value to duplicated field
                    fieldIndices.updateValue(oldIndex, forKey: encoder.field(for: codingPath))
                    return
                }
                throw EncodingError.invalidValue(unescaped as Any, .init(codingPath: codingPath, debugDescription: "Duplicated field"))
            }
            values.append(unescaped)
        }
    }
    
    func finalize() -> (fieldIndices: [String: Int], values: [String?]) {
        return (fieldIndices, values.map { $0 as? String })
    }
}

struct CSVInternalEncoder: Encoder {
    let context: EncodingContext, codingPath: [CodingKey]
    
    var userInfo: [CodingUserInfoKey: Any] { return context.userInfo }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        return KeyedEncodingContainer(CSVKeyedEncodingContainer(encoder: self))
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return CSVUnkeyedEncodingContainer(encoder: self)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

private struct CSVKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: CSVInternalEncoder

    var context: EncodingContext { return encoder.context }
    var codingPath: [CodingKey] { return encoder.codingPath }
    
    private func codingPath(forKey key: CodingKey) -> [CodingKey] {
        return codingPath + [key]
    }

    private func encoder(forKey key: CodingKey) -> CSVInternalEncoder {
        return .init(context: context, codingPath: codingPath(forKey: key))
    }

    mutating func encodeNil(forKey key: Key) throws { try context.add(unescaped: nil, to: codingPath(forKey: key)) }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable, T: LosslessStringConvertible {
        try context.add(unescaped: String(value), to: codingPath(forKey: key))
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        try value.encode(to: encoder(forKey: key))
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        return .init(CSVKeyedEncodingContainer<NestedKey>(encoder: encoder(forKey: key)))
    }
    
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return CSVUnkeyedEncodingContainer(encoder: encoder(forKey: key))
    }

    mutating func superEncoder() -> Encoder { return encoder(forKey: SuperCodingKey()) }
    mutating func superEncoder(forKey key: Key) -> Encoder { return encoder(forKey: key) }

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

private struct CSVUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let encoder: CSVInternalEncoder

    var count = 0

    var context: EncodingContext { return encoder.context }
    var codingPath: [CodingKey] { return encoder.codingPath }

    init(encoder: CSVInternalEncoder) {
        self.encoder = encoder
    }
    
    private mutating func consumeCodingPath() -> [CodingKey] {
        defer { count += 1 }
        return codingPath + [UnkeyedCodingKey(intValue: count)]
    }

    private mutating func consumeEncoder() -> CSVInternalEncoder {
        return .init(context: context, codingPath: consumeCodingPath())
    }
    
    mutating func encodeNil() throws { try context.add(unescaped: nil, to: consumeCodingPath()) }

    mutating func encode<T>(_ value: T) throws where T: Encodable, T: LosslessStringConvertible {
        try context.add(unescaped: String(value), to: consumeCodingPath())
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        try value.encode(to: consumeEncoder())
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        return .init(CSVKeyedEncodingContainer(encoder: consumeEncoder()))
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return CSVUnkeyedEncodingContainer(encoder: consumeEncoder())
    }

    mutating func superEncoder() -> Encoder { return consumeEncoder() }
}

extension CSVInternalEncoder: SingleValueEncodingContainer {
    mutating func encodeNil() throws {
        try context.add(unescaped: nil, to: codingPath)
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable, T: LosslessStringConvertible {
        try context.add(unescaped: String(value), to: codingPath)
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        try value.encode(to: self)
    }
}
