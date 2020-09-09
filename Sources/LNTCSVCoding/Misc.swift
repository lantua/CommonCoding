//
//  Misc.swift
//  LNTCSVCoding
//
//  Created by Natchanon Luangsomboon on 1/8/2562 BE.
//

extension String {
    /// Returns escaped string (including double quote) as necessary.
    func escaped(separator: Character, forced: Bool) -> String {
        if contains("\"") {
            var result = "\"", remaining = self[...]
            while let index = remaining.firstIndex(of: "\"") {
                result.append(contentsOf: remaining[...index])
                result.append("\"")
                remaining = remaining[index...].dropFirst()
            }
            result.append(contentsOf: remaining)
            result.append("\"")
            return result
        }

        func isPrintable(_ character: Character) -> Bool {
            character.asciiValue.map { 0x20...0x7E ~= $0 } ?? false
        }

        if forced || contains(separator) || !allSatisfy(isPrintable) {
            return "\"\(self)\""
        }
        return self
    }
}
