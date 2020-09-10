//
//  Public.swift
//  LNTCSVCoding
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

import LNTSharedCoding

let separator: Character = ","

public struct CSVEncodingOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Don't write header line
    public static let omitHeader        = CSVEncodingOptions(rawValue: 1 << 0)
    /// Force escape every value
    public static let alwaysQuote       = CSVEncodingOptions(rawValue: 1 << 1)
    /// Use unescaped "null" as nil value
    public static let useNullAsNil      = CSVEncodingOptions(rawValue: 1 << 2)
}

public struct CSVEncoder {
    public var options: CSVEncodingOptions
    public var userInfo: [CodingUserInfoKey: Any]
    
    let subheaderSeparator: Character
    
    public init(subheaderSeparator: Character = ".", options: CSVEncodingOptions = [], userInfo: [CodingUserInfoKey: Any] = [:]) {
        self.subheaderSeparator = subheaderSeparator
        self.options = options
        self.userInfo = userInfo
    }

    private func escape(_ string: String?) -> String {
        switch string {
        case nil: return options.contains(.useNullAsNil) ? "null" : ""
        case "null" where options.contains(.useNullAsNil): return "\"null\""
        case let string?:
            return string.escaped(separator: separator, forced: options.contains(.alwaysQuote))
        }
    }

    public func encode<S>(_ values: S) throws -> String where S: Sequence, S.Element: Encodable {
        var result = ""
        try encode(values, into: &result)
        return result
    }
    
    public func encode<S, Output>(_ values: S, into output: inout Output) throws where S: Sequence, S.Element: Encodable, Output: TextOutputStream {
        var fieldIndices: [String: Int]?
        
        for value in values {
            let context = SharedEncodingContext(encoder: self, fieldIndices: fieldIndices)
            let encoder = CSVInternalEncoder(context: .init(context, userInfo: userInfo))
            try value.encode(to: encoder)
            
            let (currentFieldIndices, entry) = context.finalize()
            assert(Set(currentFieldIndices.values) == Set(0..<currentFieldIndices.count))
            assert(currentFieldIndices.count == entry.count)
            
            if fieldIndices == nil {
                fieldIndices = currentFieldIndices
                if !options.contains(.omitHeader) {
                    let header = currentFieldIndices.sorted { $0.value < $1.value }.map { $0.key }
                    print(header.joined(separator: String(separator)), to: &output)
                }
            }
            assert(currentFieldIndices.allSatisfy { fieldIndices![$0.key] == $0.value })

            print(entry.map(escape).joined(separator: String(separator)), to: &output)
        }
    }
}

public struct CSVDecodingOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Treat unescaped "" as non-nil empty string, also applied to header
    public static let treatEmptyStringAsValue   = CSVDecodingOptions(rawValue: 1 << 0)
    /// Treat unescaped "null" as nil value, also applied to header
    public static let treatNullAsNil            = CSVDecodingOptions(rawValue: 1 << 1)
}

public struct CSVDecoder {
    public var options: CSVDecodingOptions
    public var userInfo: [CodingUserInfoKey: Any]

    public var subheaderSeparator: Character

    public init(subheaderSeparator: Character = ".", options: CSVDecodingOptions = [], userInfo: [CodingUserInfoKey: Any] = [:]) {
        self.subheaderSeparator = subheaderSeparator
        self.options = options
        self.userInfo = userInfo
    }
    
    public func decode<S, T>(_ type: T.Type, from string: S) throws -> [T] where S: StringProtocol, T: Decodable {
        var buffer: [String?] = [], schema: Schema!, fieldCount: Int?, results: [T] = []
        for token in Tokens(base: string) {
            switch token {
            case let .escaped(string): buffer.append(string)
            case let .unescaped(string):
                guard !options.contains(.treatNullAsNil) || string.lowercased() != "null",
                    options.contains(.treatEmptyStringAsValue) || !string.isEmpty else {
                        buffer.append(nil)
                        break
                }

                buffer.append(string)
            case let .invalid(error):
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid CSV format", underlyingError: error))
            case .rowBoundary:
                defer { buffer.removeAll(keepingCapacity: true) }
                
                guard fieldCount != nil else {
                    fieldCount = buffer.count

                    schema = try Schema(data: Array(buffer.map {
                        ($0?.split(separator: subheaderSeparator) ?? [])[...]
                        }.enumerated()))
                    continue
                }

                guard buffer.count == fieldCount else {
                    throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Each row must have equal number of fields"))
                }

                let decoder = CSVInternalDecoder(decoder: self, values: buffer, schema: schema)
                try results.append(T(from: decoder))
            }
        }
       
        assert(buffer.isEmpty)
        return results
    }
}
