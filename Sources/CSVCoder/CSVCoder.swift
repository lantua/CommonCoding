public struct CSVEncoder {
    public var options: CSVEncodingOptions = []
    public var userInfo: [CodingUserInfoKey: Any] = [:]
    
    private let separator: Character, subheaderSeparator: String
    
    init(separator: Character = ",", subheaderSeparator: Character = ".") {
        self.separator = separator
        self.subheaderSeparator = String(subheaderSeparator)
    }

    func escape(_ value: String) -> String {
        return value.escaped(separator: separator, forced: options.contains(.alwaysQuote))
    }

    func field(for path: [CodingKey]) -> String {
        return path.map { $0.stringValue }.joined(separator: subheaderSeparator)
    }

    func encode<S>(_ values: S) throws -> String where S: Sequence, S.Element: Encodable {
        var result = ""
        try encode(values, into: &result)
        return result
    }
    
    func encode<S, Output>(_ values: S, into output: inout Output) throws where S: Sequence, S.Element: Encodable, Output: TextOutputStream {
        var fields: [String]?
        let stringSeparator = String(separator)
        
        for value in values {
            let context: EncodingContext
            if !options.contains(.nonHomogeneous),
                let fields = fields {
                context = try ConstrainedEncodingContext(encoder: self, fields: fields)
            } else {
                context = UnconstraintedEncodingContext(encoder: self)
            }
            
            let encoder = CSVInternalEncoder(context: context, codingPath: [])
            try value.encode(to: encoder)
            
            let (newFields, entry) = context.finalize()
            
            if fields == nil {
                fields = newFields
                if !options.contains(.skipHeader) {
                    print(newFields.joined(separator: stringSeparator), to: &output)
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
    
    func decode<S, T>(_ type: T.Type, _ string: S) throws -> [T] where T: Decodable, S: StringProtocol {
        let tokens = UnescapedCSVTokens(base: string, separator: separator)
        
        var buffer: [String] = [], headers: Trie?, results: [T] = []
        for token in tokens {
            switch token {
            case let .token(subsequence, isLastInLine: false):
                buffer.append(subsequence)
            case let .token(subsequence, isLastInLine: true):
                buffer.append(subsequence)
                defer { buffer.removeAll(keepingCapacity: true) }
                
                guard let currentHeaders = headers else {
                    headers = Trie()
                    for (offset, field) in buffer.enumerated() {
                        let path = field.split(separator: subheaderSeparator).map(String.init)
                        guard headers!.add(offset, to: path) else {
                            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Duplicated key \(field)"))
                        }
                    }
                    continue
                }

                if buffer.count == 1 && buffer.first!.allSatisfy({ $0.isWhitespace }) {
                    // Skip empty row
                    continue
                }
                
                let context = try DecodingContext(decoder: self, data: buffer)
                let decoder = CSVInternalDecoder(context: context, headers: currentHeaders, codingPath: [])
                try results.append(T(from: decoder))
            case .invalid:
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid CSV format"))
            }
        }
       
        assert(buffer.isEmpty)
        return results
    }
}

