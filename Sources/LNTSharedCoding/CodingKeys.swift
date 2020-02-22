//
//  CodingKeys.swift
//  
//
//  Created by Natchanon Luangsomboon on 22/2/2563 BE.
//

import Foundation

/// Coding key for UnkeyedEn/DecodingContainer.
public struct UnkeyedCodingKey: CodingKey {
    var index: Int

    public var intValue: Int? { return index }
    public var stringValue: String { return String(index) }

    public init(intValue: Int) {
        index = intValue
    }
    public init?(stringValue: String) {
        guard let value = Int(stringValue) else {
            return nil
        }
        index = value
    }
}

/// Coding key for `super` encoder.
public struct SuperCodingKey: CodingKey {
    public var intValue: Int? { return 0 }
    public var stringValue: String { return "super" }

    public init?(intValue: Int) {
        if intValue != 0 {
            return nil
        }
    }
    public init?(stringValue: String) {
        if stringValue != "super" {
            return nil
        }
    }
    public init() { }
}
