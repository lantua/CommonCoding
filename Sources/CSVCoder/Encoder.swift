//
//  Encoder.swift
//  CSVCoder
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
                if unescaped == nil {
                    // It's fine to add `nil` to non-existing field
                    return
                }
                throw EncodingError.invalidValue(unescaped as Any, .init(codingPath: codingPath, debugDescription: "Key does not match any header fields"))
            }
            if let oldValue = values[index] {
                if oldValue == unescaped {
                    // It's fine to add same value to duplicated field
                    return
                }
                throw EncodingError.invalidValue(unescaped as Any, .init(codingPath: codingPath, debugDescription: "Duplicated field"))
            }
            
            values[index] = unescaped
        } else {
            if let oldIndex = fieldIndices.updateValue(values.count, forKey: encoder.field(for: codingPath)) {
                if values[oldIndex]! == unescaped {
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
        return KeyedEncodingContainer(CSVKeyedEncodingContainer(context: context, codingPath: codingPath))
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return CSVUnkeyedEncodingContainer(context: context, codingPath: codingPath)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return CSVSingleValueEncodingContainer(context: context, codingPath: codingPath)
    }
}

private struct CSVKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let context: EncodingContext, codingPath: [CodingKey]
    
    private func codingPath(for key: CodingKey) -> [CodingKey] {
        return codingPath + [key]
    }

    mutating func encodeNil(forKey key: Key) throws { try context.add(unescaped: nil, to: codingPath(for: key)) }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable, T: LosslessStringConvertible {
        try context.add(unescaped: String(value), to: codingPath(for: key))
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        try value.encode(to: CSVInternalEncoder(context: context, codingPath: codingPath(for: key)))
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        return KeyedEncodingContainer(CSVKeyedEncodingContainer<NestedKey>(context: context, codingPath: codingPath(for: key)))
    }
    
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return CSVUnkeyedEncodingContainer(context: context, codingPath: codingPath(for: key))
    }
    
    mutating func superEncoder() -> Encoder {
        return CSVInternalEncoder(context: context, codingPath: codingPath(for: SuperCodingKey()))
    }
    
    mutating func superEncoder(forKey key: Key) -> Encoder {
        return CSVInternalEncoder(context: context, codingPath: codingPath(for: key))
    }

    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws {
        guard let value = value else {
            try encodeNil(forKey: key)
            return
        }
        try encode(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init(_:)), forKey: key) }
    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init(_:)), forKey: key) }
    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init(_:)), forKey: key) }
    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init(_:)), forKey: key) }
    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init(_:)), forKey: key) }
    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init(_:)), forKey: key) }
    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init(_:)), forKey: key) }
    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init(_:)), forKey: key) }
    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws { try encodeIfPresent(value.map(String.init), forKey: key) }
}

private struct CSVUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let context: EncodingContext, codingPath: [CodingKey]
    var count = 0
    
    init(context: EncodingContext, codingPath: [CodingKey]) {
        self.context = context
        self.codingPath = codingPath
    }
    
    private mutating func consumeCodingPath() -> [CodingKey] {
        let key = UnkeyedCodingKey(intValue: count)
        count += 1
        return codingPath + [key]
    }
    
    mutating func encodeNil() throws { try context.add(unescaped: nil, to: consumeCodingPath()) }

    mutating func encode<T>(_ value: T) throws where T: Encodable, T: LosslessStringConvertible {
        try context.add(unescaped: String(value), to: consumeCodingPath())
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        try value.encode(to: CSVInternalEncoder(context: context, codingPath: consumeCodingPath()))
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        return KeyedEncodingContainer(CSVKeyedEncodingContainer(context: context, codingPath: consumeCodingPath()))
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return CSVUnkeyedEncodingContainer(context: context, codingPath: consumeCodingPath())
    }
    
    mutating func superEncoder() -> Encoder {
        return CSVInternalEncoder(context: context, codingPath: consumeCodingPath())
    }
}

private struct CSVSingleValueEncodingContainer: SingleValueEncodingContainer {
    let context: EncodingContext, codingPath: [CodingKey]

    mutating func encodeNil() throws {
        try context.add(unescaped: nil, to: codingPath)
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable, T: LosslessStringConvertible {
        try context.add(unescaped: String(value), to: codingPath)
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        try value.encode(to: CSVInternalEncoder(context: context, codingPath: codingPath))
    }
}
