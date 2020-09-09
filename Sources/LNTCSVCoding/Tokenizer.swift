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
            case expecting, rowBoundary, end
        }
        var remaining: S.SubSequence, state = State.expecting

        mutating func next() -> Token? {
            switch state {
            case .expecting:
                defer {
                    if remaining.first != separator, state != .end {
                        state = .rowBoundary
                    }
                    remaining = remaining.dropFirst()
                }

                guard remaining.first != "\"" else {
                    // Escaping
                    remaining.removeFirst()
                    var escaped = ""
                    while let index = remaining.firstIndex(of: "\"") {
                        escaped.append(contentsOf: remaining[..<index])
                        remaining = remaining[remaining.index(after: index)...]

                        let first = remaining.first
                        switch first {
                        case "\"":
                            remaining.removeFirst()
                            escaped.append("\"")
                        case _ where first?.isNewline ?? true, separator:
                            return .escaped(escaped)
                        default:
                            state = .end
                            return .invalid(.invalidEscaping(first!))
                        }
                    }

                    state = .end
                    return .invalid(.unclosedQoute)
                }

                // Non-escaping
                let pivot = remaining.firstIndex { $0 == separator || $0.isNewline } ?? remaining.endIndex
                let unescaped = remaining[..<pivot]
                remaining = remaining[pivot...]

                guard !unescaped.contains("\"") else {
                    state = .end
                    return .invalid(.unescapedQuote)
                }

                return .unescaped(.init(unescaped))
            case .rowBoundary:
                state = remaining.isEmpty ? .end : .expecting
                return .rowBoundary
            case .end: return nil
            }
        }
    }

    func makeIterator() -> Iterator { Iterator(remaining: base[...]) }
}
