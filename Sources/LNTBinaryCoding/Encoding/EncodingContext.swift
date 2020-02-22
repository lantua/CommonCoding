//
//  EncodingContext.swift
//  
//
//  Created by Natchanon Luangsomboon on 19/2/2563 BE.
//

import Foundation
import LNTSharedCoding

struct EncodingContext {
    fileprivate class Shared {
        let userInfo: [CodingUserInfoKey: Any]
        var strings: [String: Int] = [:]

        init(userInfo: [CodingUserInfoKey: Any]) {
            self.userInfo = userInfo
        }
    }

    fileprivate let shared: Shared
    var path: CodingPath = .root

    var userInfo: [CodingUserInfoKey: Any] { shared.userInfo }
    var codingPath: [CodingKey] { path.codingPath }

    init(userInfo: [CodingUserInfoKey: Any]) {
        shared = .init(userInfo: userInfo)
    }

    func register(string: String) {
        shared.strings[string, default: 0] += 1
    }

    func optimize() -> [String] {
        shared.strings.sorted { $0.1 > $1.1 }.map { $0.key }
    }
}

extension EncodingContext {
    func appending(_ key: CodingKey) -> EncodingContext {
        var temp = self
        temp.path = .child(key: key, parent: path)
        return temp
    }
}
