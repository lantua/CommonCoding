//
//  Tokenizer.swift
//  LNTCSVCoding
//
//  Created by Natchanon Luangsomboon on 5/8/2562 BE.
//

/// Sequence of tokens given the csv content. The tokens may be de-escaped
/// string (with escaping information), row boundary, and parsing error.
struct UnescapedCSVTokens<S: StringProtocol>: Sequence {
    let base: S

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

    struct Iterator: IteratorProtocol {
        enum State {
            case expecting, rowBoundary, ended
        }

        var remaining: S.SubSequence, state = State.expecting

        /// Consumes a token and one character after it (if it exists).
        mutating func nextToken() throws -> (Token, separator: Bool) {
            defer { remaining = remaining.dropFirst() }

            let first = remaining.first
            switch first {
            case _ where first?.isNewline ?? true, separator:
                return (.unescaped(""), first == separator)
            case "\"":
                // Escaping
                var escaped = ""

                remaining.removeFirst()
                while let index = remaining.firstIndex(of: "\"") {
                    escaped.append(contentsOf: remaining.prefix(upTo: index))
                    remaining = remaining.suffix(from: remaining.index(after: index))

                    let current = remaining.first
                    switch current {
                    case "\"": escaped.append(contentsOf: "\"")
                    case _ where current?.isNewline ?? true, separator:
                        return (.escaped(escaped), current == separator)
                    default: throw TokenizationError.invalidEscaping(current!)
                    }

                    remaining.removeFirst()
                }

                throw TokenizationError.unclosedQoute
            default:
                // Non-escaping
                let pivot = remaining.firstIndex { $0 == separator || $0.isNewline } ?? remaining.endIndex
                let unescaped = remaining.prefix(upTo: pivot)
                remaining = remaining.suffix(from: pivot)

                guard !unescaped.contains("\"") else {
                    throw TokenizationError.unescapedQuote
                }

                return (.unescaped(String(unescaped)), remaining.first == separator)
            }
        }

        mutating func next() -> Token? {
            do {
                switch state {
                case .expecting:
                    let (token, separator) = try nextToken()
                    state = separator ? .expecting : .rowBoundary
                    return token
                case .rowBoundary:
                    state = remaining.isEmpty ? .ended : .expecting
                    return .rowBoundary
                case .ended: return nil
                }
            } catch {
                state = .ended
                return .invalid(error as! TokenizationError)
            }
        }
    }

    func makeIterator() -> Iterator {
        return Iterator(remaining: base[...])
    }
}
