//
//  Misc.swift
//  CSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

extension String {
    func escaped(separator: Character, forced: Bool) -> String {
        func needEscaping(_ character: Character) -> Bool {
            guard character != separator,
                !character.isNewline,
                let asciiValue = character.asciiValue else {
                    return true
            }
            
            switch asciiValue {
            case 0x22: // Double quote
                return true
            case 0x20...0x7E: // Printable ASCII
                return false
            default:
                // non-printable characters
                // Not sure how escaping would help, but well, we tried...
                return true
            }
        }
        
        let shouldEscape = forced || contains(where: needEscaping)
        
        guard contains("\"") else {
            return shouldEscape ? "\"\(self)\"" : self
        }
        assert(shouldEscape)

        return reduce(into: "\"") {
            switch ($1) {
            case "\"": $0.append("\"\"")
            default: $0.append($1)
            }
        } + "\""
    }
}

struct UnescapedCSVTokens<S: Sequence>: Sequence where S.Element == Character {
    let base: S, separator: Character
    
    enum Token {
        case escaped(String), unescaped(String), rowBoundary, invalid(TokenizationError)
    }
    
    enum TokenizationError: Error {
        /// Text has unescaped double quote
        case unescapedQuote
        /// Text has double quote followed by non-escaping character
        case invalidEscaping(Character)
        /// Text has opening double quote, but not closing one
        case unclosedQoute
    }
    
    /// Sequence of token, and whether or not boundary is
    /// - Attention: Do NOT call `next` after it returns (.invalid, _)
    private struct StatelessIterator: IteratorProtocol {
        let separator: Character
        var iterator: S.Iterator
        
        mutating func next() -> (Token, nextIsSeparator: Bool)? {
            guard let first = iterator.next() else {
                // This is the only `nil` return. So it would follow `Iterator` convention
                // of repeating `nil` post-sequence if the base `iterator` follows it.
                return nil
            }
            
            switch first {
            case separator: return (.unescaped(""), true)
            case _ where first.isNewline: return (.unescaped(""), false)
            case "\"":
                // Escaping
                var unescaped = "", isEscaping = false
                
                while let current = iterator.next() {
                    guard !isEscaping else {
                        switch current {
                        case "\"":
                            isEscaping = false
                            unescaped.append(current)
                            continue
                        case separator: return (.escaped(unescaped), true)
                        case _ where current.isNewline: return (.escaped(unescaped), false)
                        default: return (.invalid(.invalidEscaping(current)), false)
                        }
                    }
                    if current == "\"" {
                        isEscaping = true
                    } else {
                        unescaped.append(current)
                    }
                }
                
                return isEscaping ? (.escaped(unescaped), false) : (.invalid(.unclosedQoute), false)
            default:
                // Non-escaping
                var unescaped = String(first)
                while let current = iterator.next() {
                    switch current {
                    case "\"": return (.invalid(.unescapedQuote), false)
                    case separator: return (.unescaped(unescaped), true)
                    case _ where current.isNewline: return (.unescaped(unescaped), false)
                    default: unescaped.append(current)
                    }
                }
                
                return (.unescaped(unescaped), false)
            }
        }
    }
    
    struct Iterator: IteratorProtocol {
        private enum State {
            case expecting, nonexpecting, rowBoundary, ended
        }

        private var iterator: StatelessIterator, state = State.expecting
        
        init(separator: Character, iterator: S.Iterator) {
            self.iterator = StatelessIterator(separator: separator, iterator: iterator)
        }
        
        mutating func next() -> Token? {
            switch state {
            case .ended: return nil
            case.rowBoundary:
                state = .nonexpecting
                return .rowBoundary
            case .expecting, .nonexpecting:
                guard let (token, isSeparator) = iterator.next() else {
                    if state == .expecting {
                        state = .rowBoundary
                        return .unescaped("")
                    }
                    
                    state = .ended
                    return nil
                }
                
                if case .invalid = token {
                    state = .ended
                } else if isSeparator {
                    state = .expecting
                } else {
                    state = .rowBoundary
                }
                
                return token
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
