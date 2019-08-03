public struct CSVEncoder {
    public var options: CSVEncodingOptions = []
    public var userInfo: [CodingUserInfoKey: Any] = [:]
    
    private let separator: Character, subheaderSeparator: String
    
    public init(separator: Character = ",", subheaderSeparator: Character = ".") {
        self.separator = separator
        self.subheaderSeparator = String(subheaderSeparator)
    }

    func escape(_ value: String) -> String {
        return value.escaped(separator: separator, forced: options.contains(.alwaysQuote))
    }

    func field(for path: [CodingKey]) -> String {
        return path.map { $0.stringValue }.joined(separator: subheaderSeparator)
    }

    public func encode<S>(_ values: S) throws -> String where S: Sequence, S.Element: Encodable {
        var result = ""
        try encode(values, into: &result)
        return result
    }
    
    public func encode<S, Output>(_ values: S, into output: inout Output) throws where S: Sequence, S.Element: Encodable, Output: TextOutputStream {
        let stringSeparator = String(separator)
        var fieldLocations: [String: Int]?
        
        for value in values {
            let context = EncodingContext(encoder: self, fieldLocations: options.contains(.nonHomogeneous) ? nil : fieldLocations)
            let encoder = CSVInternalEncoder(context: context, codingPath: [])
            try value.encode(to: encoder)
            
            let (newFieldLocations, entry) = context.finalize()
            
            if fieldLocations == nil {
                fieldLocations = newFieldLocations
                if !options.contains(.skipHeader) {
                    let fields = newFieldLocations.sorted { $0.value < $1.value }
                    assert(fields.map { $0.value } == Array(0..<fields.count))
                    print(fields.map { $0.key }.joined(separator: stringSeparator), to: &output)
                }
            }
            print(entry.joined(separator: stringSeparator), to: &output)
        }
    }
}

public struct CSVDecoder {
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    private let separator, subheaderSeparator: Character
    
    public init(separator: Character = ",", subheaderSeparator: Character = ".") {
        self.separator = separator
        self.subheaderSeparator = subheaderSeparator
    }
    
    public func decode<S, T>(_ type: T.Type, from string: S) throws -> [T] where S: Sequence, S.Element == Character, T: Decodable {
        var buffer: [String] = [], fields: Trie<Int>?, fieldCount: Int!, results: [T] = []
        for token in UnescapedCSVTokens(base: string, separator: separator) {
            switch token {
            case let .token(string): buffer.append(string)
            case .invalid: throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid CSV format"))
            case .rowBoundary:
                defer { buffer.removeAll(keepingCapacity: true) }
                
                guard let currentHeaders = fields else {
                    fields = Trie()
                    fieldCount = buffer.count
                    for (offset, field) in buffer.enumerated() {
                        let path = field.split(separator: subheaderSeparator).map(String.init)
                        guard fields!.add(offset, to: path) == nil else {
                            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Duplicated field \(field)"))
                        }
                    }
                    continue
                }

                if buffer.count == 1 && buffer.first!.allSatisfy({ $0.isWhitespace }) {
                    // Skip empty row
                    continue
                }
                
                guard buffer.count == fieldCount else {
                    throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Each row must have equal number of fields"))
                }
                
                let context = DecodingContext(decoder: self, data: buffer)
                let decoder = CSVInternalDecoder(context: context, headers: currentHeaders, codingPath: [])
                try results.append(T(from: decoder))
            }
        }
       
        assert(buffer.isEmpty)
        return results
    }
}
