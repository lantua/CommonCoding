//
//  CSVEncoder.swift
//  CSVCoder
//
//  Created by Natchanon Luangsomboon on 31/7/2562 BE.
//

import Foundation

public struct CSVEncodingOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let alwaysQuote       = CSVEncodingOptions(rawValue: 1 << 0)
    public static let nonHomogeneous    = CSVEncodingOptions(rawValue: 1 << 1)
    public static let skipHeader        = CSVEncodingOptions(rawValue: 1 << 2)
}

protocol EncodingContext: AnyObject {
    var userInfo: [CodingUserInfoKey: Any] { get }
    
    func add(unescaped: String, to path: [CodingKey]) throws
    func finalize() -> (fields: [String], values: [String])
}

class UnconstraintedEncodingContext: EncodingContext {
    private let encoder: CSVEncoder
    private var fields: [String] = [], values: [String] = []

    var userInfo: [CodingUserInfoKey: Any] { return encoder.userInfo }

    init(encoder: CSVEncoder) {
        self.encoder = encoder
    }
    
    func add(unescaped: String, to codingPath: [CodingKey]) throws {
        fields.append(encoder.field(for: codingPath))
        values.append(encoder.escape(unescaped))
    }
    
    func finalize() -> (fields: [String], values: [String]) {
        return (fields, values)
    }
}

class ConstrainedEncodingContext: EncodingContext {
    private let encoder: CSVEncoder
    private let fields: [String], permitted: [String: Int]
    private var values: [String?]

    var userInfo: [CodingUserInfoKey: Any] { return encoder.userInfo }

    init(encoder: CSVEncoder, fields: [String]) throws {
        self.encoder = encoder
        self.fields = fields
        
        permitted = try Dictionary(zip(fields, 0...)) { _, key -> Int in
            throw EncodingError.invalidValue(Void.self, .init(codingPath: [], debugDescription: "Duplicated key \(key)"))
        }
        values = Array(repeating: nil, count: fields.count)
    }
    
    func add(unescaped: String, to codingPath: [CodingKey]) throws {
        guard let index = permitted[encoder.field(for: codingPath)] else {
            throw EncodingError.invalidValue(unescaped, .init(codingPath: codingPath, debugDescription: "Invalid key"))
        }
        guard values[index] == nil else {
            throw EncodingError.invalidValue(unescaped, .init(codingPath: codingPath, debugDescription: "Repeated key"))
        }
        
        values[index] = encoder.escape(unescaped)
    }
    
    func finalize() -> (fields: [String], values: [String]) {
        return (fields, values.map { $0 ?? "" })
    }
}

struct CSVInternalEncoder: Encoder {
    let context: EncodingContext, codingPath: [CodingKey]
    
    var userInfo: [CodingUserInfoKey: Any] { return context.userInfo }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        return KeyedEncodingContainer(CSVKeyedEncodingContainer(context: context, codingPath: codingPath))
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return CSVUnkeyedEncodingContainer(context: context, codingPath: codingPath, isSingle: false)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return CSVUnkeyedEncodingContainer(context: context, codingPath: codingPath, isSingle: true)
    }
}

private struct CSVKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let context: EncodingContext, codingPath: [CodingKey]
    
    private func nextPath(for key: CodingKey) -> [CodingKey] {
        return codingPath + [key]
    }

    mutating func encodeNil(forKey key: Key) throws { try encode("", forKey: key) }

    mutating func encode(_ value: String, forKey key: Key) throws {
        try context.add(unescaped: value, to: nextPath(for: key))
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable, T: LosslessStringConvertible {
        try encode(String(value), forKey: key)
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        let encoder = CSVInternalEncoder(context: context, codingPath: nextPath(for: key))
        try value.encode(to: encoder)
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        return KeyedEncodingContainer(CSVKeyedEncodingContainer<NestedKey>(context: context, codingPath: nextPath(for: key)))
    }
    
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return CSVUnkeyedEncodingContainer(context: context, codingPath: nextPath(for: key), isSingle: false)
    }
    
    mutating func superEncoder() -> Encoder {
        return CSVInternalEncoder(context: context, codingPath: nextPath(for: SuperCodingKey()))
    }
    
    mutating func superEncoder(forKey key: Key) -> Encoder {
        return CSVInternalEncoder(context: context, codingPath: nextPath(for: key))
    }

    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws { try encode(value.map(String.init(_:)) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws { try encode(value.map(String.init(_:)) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws { try encode(value.map(String.init(_:)) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws { try encode(value.map(String.init(_:)) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws { try encode(value.map(String.init(_:)) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws { try encode(value.map(String.init(_:)) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws { try encode(value.map(String.init(_:)) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws { try encode(value.map(String.init(_:)) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws { try encode(value.map(String.init(_:)) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws { try encode(value.map(String.init) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws { try encode(value.map(String.init) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws { try encode(value.map(String.init) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws { try encode(value.map(String.init) ?? "", forKey: key) }
    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws { try encode(value.map(String.init) ?? "", forKey: key) }
}

private struct CSVUnkeyedEncodingContainer: UnkeyedEncodingContainer, SingleValueEncodingContainer {
    let context: EncodingContext, codingPath: [CodingKey], isSingle: Bool
    var count = 0
    
    init(context: EncodingContext, codingPath: [CodingKey], isSingle: Bool) {
        self.context = context
        self.codingPath = codingPath
        self.isSingle = isSingle
    }
    
    private mutating func nextPath() -> [CodingKey] {
        if isSingle {
            precondition(count == 0)
            count += 1
            return codingPath
        } else {
            let key = UnkeyedCodingKey(intValue: count)
            count += 1
            return codingPath + [key]
        }
    }
    
    mutating func encodeNil() throws { try encode("") }

    mutating func encode(_ value: String) throws {
        try context.add(unescaped: value, to: nextPath())
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable, T: LosslessStringConvertible {
        try encode(String(value))
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        let encoder = CSVInternalEncoder(context: context, codingPath: nextPath())
        try value.encode(to: encoder)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        return KeyedEncodingContainer(CSVKeyedEncodingContainer(context: context, codingPath: nextPath()))
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return CSVUnkeyedEncodingContainer(context: context, codingPath: nextPath(), isSingle: isSingle)
    }
    
    mutating func superEncoder() -> Encoder {
        return CSVInternalEncoder(context: context, codingPath: nextPath())
    }
}
