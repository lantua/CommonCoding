//
//  CSVCoder.swift
//  CSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

public struct CSVEncoder {
    public var options: CSVEncodingOptions
    public var userInfo: [CodingUserInfoKey: Any]
    
    private let separator: Character, subheaderSeparator: String
    
    public init(separator: Character = ",", subheaderSeparator: Character = ".", options: CSVEncodingOptions = [], userInfo: [CodingUserInfoKey: Any] = [:]) {
        self.separator = separator
        self.subheaderSeparator = String(subheaderSeparator)
        self.options = options
        self.userInfo = userInfo
    }

    func escape(_ string: String?) -> String {
        return string?.escaped(separator: separator, forced: options.contains(.alwaysQuote)) ??
            (options.contains(.useNullasNil) ? "null" : "")
    }

    func field(for codingPath: [CodingKey]) -> String {
        return codingPath.map { $0.stringValue }.joined(separator: subheaderSeparator)
    }

    public func encode<S>(_ values: S) throws -> String where S: Sequence, S.Element: Encodable {
        var result = ""
        try encode(values, into: &result)
        return result
    }
    
    public func encode<S, Output>(_ values: S, into output: inout Output) throws where S: Sequence, S.Element: Encodable, Output: TextOutputStream {
        let separator = String(self.separator)
        var fieldIndices: [String: Int]?
        
        for value in values {
            let context = EncodingContext(encoder: self, fieldIndices: fieldIndices)
            let encoder = CSVInternalEncoder(context: context, codingPath: [])
            try value.encode(to: encoder)
            
            let (currentFieldIndices, entry) = context.finalize()
            assert(Set(currentFieldIndices.values) == Set(0..<currentFieldIndices.count))
            assert(currentFieldIndices.count == entry.count)
            
            if fieldIndices == nil {
                fieldIndices = currentFieldIndices
                if !options.contains(.omitHeader) {
                    let header = currentFieldIndices.sorted { $0.value < $1.value }.map { $0.key }
                    print(header.joined(separator: separator), to: &output)
                }
            }
            assert(fieldIndices == currentFieldIndices)

            print(entry.joined(separator: separator), to: &output)
        }
    }
}

public struct CSVDecoder {
    public var options: CSVDecodingOptions
    public var userInfo: [CodingUserInfoKey: Any]

    private let separator, subheaderSeparator: Character
    
    public init(separator: Character = ",", subheaderSeparator: Character = ".", options: CSVDecodingOptions = [], userInfo: [CodingUserInfoKey: Any] = [:]) {
        self.separator = separator
        self.subheaderSeparator = subheaderSeparator
        self.options = options
        self.userInfo = userInfo
    }
    
    public func decode<S, T>(_ type: T.Type, from string: S) throws -> [T] where S: Sequence, S.Element == Character, T: Decodable {
        var buffer: [String?] = [], fieldIndices: Trie<Int>!, fieldCount: Int!, results: [T] = []
        for token in UnescapedCSVTokens(base: string, separator: separator) {
            switch token {
            case let .escaped(string): buffer.append(string)
            case let .unescaped(string):
                guard !options.contains(.treatNullAsNil) || string.lowercased() != "null",
                    options.contains(.treatEmptyStringAsValue) || !string.isEmpty else {
                        buffer.append(nil)
                        break
                }

                buffer.append(string)
            case .invalid(let error):
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid CSV format", underlyingError: error))
            case .rowBoundary:
                defer { buffer.removeAll(keepingCapacity: true) }
                
                guard fieldIndices != nil else {
                    fieldIndices = Trie()
                    fieldCount = buffer.count
                    for (offset, field) in buffer.enumerated() {
                        let path = field?.split(separator: subheaderSeparator).map(String.init) ?? []
                        guard fieldIndices!.add(offset, to: path) == nil else {
                            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Duplicated field \(field ?? "")"))
                        }
                    }
                    continue
                }

                guard buffer.count == fieldCount else {
                    throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Each row must have equal number of fields"))
                }
                
                let context = DecodingContext(decoder: self, values: buffer)
                let decoder = CSVInternalDecoder(context: context, fieldIndices: fieldIndices, codingPath: [])
                try results.append(T(from: decoder))
            }
        }
       
        assert(buffer.isEmpty)
        return results
    }
}
