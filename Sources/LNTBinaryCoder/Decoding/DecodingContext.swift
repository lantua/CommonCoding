//
//  DecodingContext.swift
//  
//
//  Created by Natchanon Luangsomboon on 19/2/2563 BE.
//

import Foundation

struct DecodingContext {
    private let strings: [String]
    private var path: CodingPath

    let userInfo: [CodingUserInfoKey: Any]
    var codingPath: [CodingKey] { path.codingPath }

    init(userInfo: [CodingUserInfoKey: Any], data: inout Data) throws {
        guard data.count >= 2 else {
            throw BinaryDecodingError.emptyFile
        }

        guard data.removeFirst() == 0x00,
            data.removeFirst() == 0x00 else {
                throw BinaryDecodingError.invalidFileVersion
        }

        let count = try data.readInteger()

        self.userInfo = userInfo
        self.path = .root
        self.strings = try (0..<count).map { _ in
            try data.readString()
        }
    }

    func string(at index: Int) throws -> String {
        let index = index - 1
        guard strings.indices ~= index else {
            throw BinaryDecodingError.invalidStringMapIndex
        }
        return strings[index]
    }
}

extension DecodingContext {
    /// Returns new context with coding path being appended by `key`.
    func appending(_ key: CodingKey) -> DecodingContext {
        var temp = self
        temp.path = .child(key: key, parent: path)
        return temp
    }
}
