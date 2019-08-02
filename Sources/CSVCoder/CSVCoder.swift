public struct CSVEncoder {
    let separator, subheaderSeparator: Character
    
    public var options: CSVEncodingOptions = []
    public var userInfo: [CodingUserInfoKey: Any] = [:]
    
    init(separator: Character = ",", subheaderSeparator: Character = ".") {
        self.separator = separator
        self.subheaderSeparator = subheaderSeparator
    }
    
    func encode<S: Sequence>(_ values: S) throws -> String where S.Element: Encodable {
        var headers: [String]?, results: [String] = []
        let stringSeparator = String(separator)
        
        for value in values {
            let context: EncodingContext
            if !options.contains(.nonHomogeneous),
                let headers = headers {
                context = try ConstrainedEncodingContext(encoder: self, headers: headers)
            } else {
                context = UnconstraintedEncodingContext(encoder: self)
            }
            
            let encoder = CSVInternalEncoder(context: context, codingPath: [])
            try value.encode(to: encoder)
            
            let (newHeaders, newValue) = context.finalize()
            
            if headers == nil {
                results.append(newHeaders.joined(separator: stringSeparator))
                headers = newHeaders
            }
            results.append(newValue.joined(separator: stringSeparator))
        }
        
        return results.joined(separator: "\r\n")
    }
}

public struct CSVDecoder {
    let separator, subheaderSeparator: Character
    
    public var userInfo: [CodingUserInfoKey: Any] = [:]
    
    init(separator: Character = ",", subheaderSeparator: Character = ".") {
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
                        let path = field.split(separator: subheaderSeparator).map { String($0) }
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
        
        if !buffer.isEmpty,
            let currentHeaders = headers {
            let context = try DecodingContext(decoder: self, data: buffer)
            let decoder = CSVInternalDecoder(context: context, headers: currentHeaders, codingPath: [])
            try results.append(T(from: decoder))
        }
        
        return results
    }
}
