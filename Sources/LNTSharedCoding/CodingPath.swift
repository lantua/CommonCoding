//
//  CodingPath.swift
//  
//
//  Created by Natchanon Luangsomboon on 22/2/2563 BE.
//

import Foundation

/// Reconstructible coding path.
public enum CodingPath {
    case root
    indirect case child(key: CodingKey, parent: CodingPath)

    public var expanded: [CodingKey] {
        switch self {
        case .root: return []
        case let .child(key: key, parent: parent):
            return parent.expanded + CollectionOfOne(key)
        }
    }
}
