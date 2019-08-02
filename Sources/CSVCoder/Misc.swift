//
//  Misc.swift
//  CSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

extension StringProtocol {
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

struct UnescapedCSVTokens<S: Sequence>: Sequence where S.Element == Character {
    let base: S, separator: Character
    
    enum Token {
        case token(String, isLastInLine: Bool), invalid
    }
    
    struct Iterator: IteratorProtocol {
        let separator: Character
        var iterator: S.Iterator, isExpecting = true, hasEnded = false
        
        init(separator: Character, iterator: S.Iterator) {
            self.separator = separator
            self.iterator = iterator
        }
        
        mutating func next() -> Token? {
            guard !hasEnded else {
                return nil
            }
            
            guard let first = iterator.next() else {
                if isExpecting {
                    isExpecting = false
                    return .token("", isLastInLine: true)
                }
                return nil
            }
            
            switch first {
            case "\"":
                // Escaping
                var isEscaping = false, afterQuote: Character?
                var unescaped: [Character] = []
                
                while let current = iterator.next() {
                    guard !isEscaping else {
                        if current == "\"" {
                            isEscaping = false
                            unescaped.append(current)
                            continue
                        }
                        afterQuote = current
                        break
                    }
                    
                    if current == "\"" {
                        isEscaping = true
                    } else {
                        unescaped.append(current)
                    }
                }
                
                guard isEscaping else {
                    hasEnded = true
                    return .invalid
                }
                
                switch afterQuote {
                case let x? where x.isNewline:
                    fallthrough
                case separator, nil:
                    isExpecting = afterQuote == separator
                    return .token(String(unescaped), isLastInLine: afterQuote != separator)
                default:
                    hasEnded = true
                    return .invalid
                }
            case separator,
                 _ where first.isNewline:
                return .token("", isLastInLine: first != separator)
            default:
                // Non-escaping
                var isSeparator: Bool?, unescaped: [Character] = [first]
                
                while let current = iterator.next() {
                    switch current {
                    case "\"":
                        hasEnded = true
                        return .invalid
                    case _ where current.isNewline,
                         separator:
                        isSeparator = current == separator
                    default:
                        unescaped.append(current)
                        continue
                    }
                    break
                }

                isExpecting = isSeparator == true
                return .token(String(unescaped), isLastInLine: isSeparator != true)
            }
        }
    }
    
    func makeIterator() -> Iterator {
        return Iterator(separator: separator, iterator: base.makeIterator())
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
