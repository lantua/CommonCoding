//
//  Srotage.swift
//  
//
//  Created by Natchanon Luangsomboon on 29/2/2563 BE.
//

import Foundation

enum Storage {
    case `nil`
    case signed(Int64)
    case unsigned(UInt64)
    case string(String)
    case keyed([String: Storage])
    case unkeyed([Storage])
    case unparsed(Header, Data)
}

extension Storage {
    var isNil: Bool {
        switch self {
        case .nil, .unparsed(.nil, _): return true
        default: return false
        }
    }
}
