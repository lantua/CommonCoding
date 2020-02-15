//
//  Tokenizer.swift
//  LNTCSVCoder
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

/// Sequence of tokens given the csv content. The tokens may be de-escaped
/// string (with escaping information), row boundary, and parsing error.
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

    /// Sequence of de-escaped string (with escaping information), and whether or not boundary is right after the said string.
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
