//
//  Misc.swift
//  CSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

extension StringProtocol {
    fileprivate func unescaped() -> String {
        assert(first == "\"" && last == "\"")
        
        var ignoreNext = false
        return String(dropFirst().dropLast().filter { character -> Bool in
            guard !ignoreNext else {
                ignoreNext = false
                return false
            }
            
            if character == "\"" {
                ignoreNext = true
            }
            return true
        })
    }

    /// Return true if the string needs escaping (and is now escaped)
    func escaped(separator: Character, forced: Bool) -> String {
        func needEscaping(_ character: Character) -> Bool {
            guard character != separator,
                let asciiValue = character.asciiValue else {
                    return true
            }
            
            switch asciiValue {
            case 0x22: // Double quote
                return true
            case 0x20...0x7E: // Printable ASCII
                return false
            default: return true
            }
        }
        
        guard contains(where: needEscaping) else {
            return forced ? quoted() : String(self)
        }
        
        return String(flatMap { character -> [Character] in
            switch character {
            case "\"": return ["\"", "\""]
            default: return [character]
            }
        }).quoted()
    }
    
    private func quoted() -> String { return "\"\(self)\"" }
}

struct UnescapedCSVTokens<S: StringProtocol>: Sequence {
    let base: S, separator: Character
    
    enum Token {
        case token(String, isLastInLine: Bool), invalid
    }
    
    struct Iterator: IteratorProtocol {
        let separator: Character
        var residual: S.SubSequence, expecting = true
        
        init(separator: Character, residual: S.SubSequence) {
            self.separator = separator
            self.residual = residual
        }
        
        mutating func next() -> Token? {
            guard let first = residual.first else {
                if expecting {
                    expecting = false
                    return .token("", isLastInLine: true)
                }
                return nil
            }
            
            defer {
                if !residual.isEmpty {
                    let removed = residual.removeFirst()
                    assert(removed == "," || removed.isNewline)
                    expecting = removed == ","
                }
            }
            
            switch first {
            case "\"":
                // Escaping
                var wasEscapeSymbol = false, isValid = true
                let separatorIndex = residual.dropFirst().firstIndex { current -> Bool in
                    guard !wasEscapeSymbol else {
                        wasEscapeSymbol = false
                        
                        switch current {
                        case "\"": // Escaping `"`
                            return false
                        case _ where current.isNewline,
                             separator: // actually end of token
                            return true
                        default: // Invalid escaping, just bail out
                            isValid = false
                            return true
                        }
                    }
                    
                    wasEscapeSymbol = current == "\""
                    return false
                }
                
                guard isValid else {
                    residual = residual.prefix(0)
                    return .invalid
                }
                
                let endIndex: S.Index
                if let separatorIndex = separatorIndex {
                    endIndex = separatorIndex
                } else if wasEscapeSymbol {
                    endIndex = residual.endIndex
                } else {
                    residual = residual.prefix(0)
                    return .invalid
                }
                
                let result = residual.prefix(upTo: endIndex)
                residual = residual.suffix(from: endIndex)
                return .token(result.unescaped(), isLastInLine: residual.first != separator)
            case separator,
                 _ where first.isNewline:
                return .token("", isLastInLine: residual.first != separator)
            default:
                // Non-escaping
                var isValid = true
                let result = residual.prefix { current -> Bool in
                    switch current {
                    case "\"":
                        isValid = false
                        return false
                    case separator,
                         _ where current.isNewline:
                        return false
                    default: return true
                    }
                }
                
                if isValid {
                    residual = residual.suffix(from: result.endIndex)
                    return .token(String(result),  isLastInLine: residual.first != separator)
                } else {
                    residual = residual.prefix(0)
                    return .invalid
                }
            }
        }
    }
    
    func makeIterator() -> Iterator {
        return Iterator(separator: separator, residual: base[...])
    }
}

struct UnkeyedCodingKey: CodingKey {
    var index: Int
    
    var intValue: Int? { return index }
    var stringValue: String { return String(index) }
    
    init(intValue: Int) {
        index = intValue
    }
    init?(stringValue: String) {
        guard let value = Int(stringValue) else {
            return nil
        }
        index = value
    }
}

struct SuperCodingKey: CodingKey {
    var intValue: Int? { return 0 }
    var stringValue: String { return "super" }
    
    init?(intValue: Int) {
        if intValue != 0 {
            return nil
        }
    }
    init?(stringValue: String) {
        if stringValue != "super" {
            return nil
        }
    }
    init() { }
}
