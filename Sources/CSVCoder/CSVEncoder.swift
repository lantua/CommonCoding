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
}

protocol EncodingContext: AnyObject {
    var options: CSVEncodingOptions { get }
    var userInfo: [CodingUserInfoKey: Any] { get }
    
    func add(unescaped: String, to header: [CodingKey]) throws
    func finalize() -> (header: [String], value: [String])
}

class UnconstraintedEncodingContext: EncodingContext {
    private let encoder: CSVEncoder
    
    private var headers: [String] = []
    private var values: [String] = []

    var options: CSVEncodingOptions { return encoder.options }
    var userInfo: [CodingUserInfoKey: Any] { return encoder.userInfo }
    var separator: Character { return encoder.separator }
    var subheaderSeparator: String

    init(encoder: CSVEncoder) {
        self.encoder = encoder
        self.subheaderSeparator = String(encoder.subheaderSeparator)
    }
    
    private func escape(_ value: String) -> String {
        return value.escaped(separator: separator, forced: options.contains(.alwaysQuote))
    }
    
    func add(unescaped: String, to header: [CodingKey]) throws {
        headers.append(header.map { $0.stringValue }.joined(separator: subheaderSeparator))
        values.append(escape(unescaped))
    }
    
    func finalize() -> (header: [String], value: [String]) {
        return (headers, values)
    }
}

class ConstrainedEncodingContext: EncodingContext {
    private let encoder: CSVEncoder
    let permitted: [String: Int], headers: [String]

    var options: CSVEncodingOptions { return encoder.options }
    var userInfo: [CodingUserInfoKey: Any] { return encoder.userInfo }
    var separator: Character { return encoder.separator }
    let subheaderSeparator: String

    private var values: [String?]
    
    init(encoder: CSVEncoder, headers: [String]) throws {
        self.encoder = encoder
        self.subheaderSeparator = String(encoder.subheaderSeparator)
        self.headers = headers
        
        permitted = try Dictionary(zip(headers, 0...)) { _, key -> Int in
            throw EncodingError.invalidValue(Void.self, .init(codingPath: [], debugDescription: "Duplicated key \(key)"))
        }
        values = Array(repeating: nil, count: headers.count)
    }
    
    private func escape(_ value: String) -> String {
        return value.escaped(separator: separator, forced: options.contains(.alwaysQuote))
    }
    
    func add(unescaped: String, to header: [CodingKey]) throws {
        let headerString = header.map { $0.stringValue }.joined(separator: subheaderSeparator)
        guard let index = permitted[headerString] else {
            throw EncodingError.invalidValue(unescaped, .init(codingPath: header, debugDescription: "Invalid key"))
        }
        guard values[index] == nil else {
            throw EncodingError.invalidValue(unescaped, .init(codingPath: header, debugDescription: "Repeated key"))
        }
        
        values[index] = escape(unescaped)
    }
    
    func finalize() -> (header: [String], value: [String]) {
        return (headers, values.map { $0 ?? "" })
    }
}

struct CSVInternalEncoder: Encoder {
    let context: EncodingContext, codingPath: [CodingKey]
    
    var userInfo: [CodingUserInfoKey : Any] { return context.userInfo }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
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

    mutating func encodeNil(forKey key: Key) throws { try encode(unescaped: "", forKey: key) }
    mutating func encode(_ value: Bool, forKey key: Key) throws { try encode(unescaped: value ? "true" : "false", forKey: key) }
    mutating func encode(_ value: Double, forKey key: Key) throws { try encode(unescaped: String(value), forKey: key) }
    mutating func encode(_ value: Float, forKey key: Key) throws { try encode(unescaped: String(value), forKey: key) }
    mutating func encode(_ value: String, forKey key: Key) throws { try encode(unescaped: value, forKey: key) }
    mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable, T : FixedWidthInteger {
        try encode(unescaped: String(value), forKey: key)
    }
    
    private mutating func encode(unescaped: String, forKey key: Key) throws {
        try context.add(unescaped: unescaped, to: nextPath(for: key))
    }
    
    mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        let encoder = CSVInternalEncoder(context: context, codingPath: nextPath(for: key))
        try value.encode(to: encoder)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
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
}

private struct CSVUnkeyedEncodingContainer: UnkeyedEncodingContainer, SingleValueEncodingContainer {
    let context: EncodingContext, codingPath: [CodingKey]
    var count = 0
    let isSingle: Bool
    
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
    
    mutating func encodeNil() throws { try encode(unescaped: "") }
    mutating func encode(_ value: Bool) throws { try encode(unescaped: value ? "true": "false") }
    mutating func encode(_ value: Double) throws { try encode(unescaped: String(value)) }
    mutating func encode(_ value: Float) throws { try encode(unescaped: String(value)) }
    mutating func encode(_ value: String) throws { try encode(unescaped: value) }
    mutating func encode<T>(_ value: T) throws where T : Encodable, T : FixedWidthInteger {
        try encode(unescaped: String(value))
    }

    private mutating func encode(unescaped: String) throws {
        try context.add(unescaped: unescaped, to: nextPath())
    }
    mutating func encode<T>(_ value: T) throws where T : Encodable {
        let encoder = CSVInternalEncoder(context: context, codingPath: nextPath())
        try value.encode(to: encoder)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        return KeyedEncodingContainer(CSVKeyedEncodingContainer(context: context, codingPath: nextPath()))
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return CSVUnkeyedEncodingContainer(context: context, codingPath: nextPath(), isSingle: isSingle)
    }
    
    mutating func superEncoder() -> Encoder {
        return CSVInternalEncoder(context: context, codingPath: nextPath())
    }
}
