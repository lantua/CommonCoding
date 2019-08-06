//
//  Misc.swift
//  CSVCoder
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

import Common

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
