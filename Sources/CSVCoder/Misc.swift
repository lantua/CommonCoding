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
        case token(String), rowBoundary, invalid
    }
    
    /// Sequence of token, and whether or not boundary is
    /// - Attention: Do NOT call `next` after it returns (.invalid, _)
    private struct StatelessIterator: IteratorProtocol {
        let separator: Character
        var iterator: S.Iterator
        
        mutating func next() -> (Token, nextIsSeparator: Bool)? {
            guard let first = iterator.next() else {
                return nil
            }
            
            switch first {
            case separator: return (.token(""), true)
            case _ where first.isNewline: return (.token(""), false)
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
                        case separator: return (.token(unescaped), true)
                        case _ where current.isNewline: return (.token(unescaped), false)
                        default: return (.invalid, false)
                        }
                    }
                    if current == "\"" {
                        isEscaping = true
                    } else {
                        unescaped.append(current)
                    }
                }
                
                return isEscaping ? (.token(unescaped), false) : (.invalid, false)
            default:
                // Non-escaping
                var unescaped = String(first)
                while let current = iterator.next() {
                    switch current {
                    case "\"": return (.invalid, false)
                    case separator: return (.token(unescaped), true)
                    case _ where current.isNewline: return (.token(unescaped), false)
                    default: unescaped.append(current)
                    }
                }
                
                return (.token(unescaped), false)
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
                        return .token("")
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
