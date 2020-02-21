//
//  DecodingHeaders.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation

extension RegularKeyedHeader {
    init(data: inout Data) throws {
        var mapping: [(key: Int, size: Int)] = []
        var size = try data.readInteger()
        while size != 1 {
            let key = try data.readInteger()
            mapping.append((key, size))

            size = try data.readInteger()
        }

        self.mapping = mapping
    }
}

extension EquisizedKeyedHeader {
    init(data: inout Data) throws {
        var keys: [Int] = []

        let size = try data.readInteger()
        var keyIndex = try data.readInteger()
        while keyIndex != 0 {
            keys.append(keyIndex)
            keyIndex = try data.readInteger()
        }

        self.size = size
        self.keys = keys
    }
}

extension UniformKeyedHeader {
    init(data: inout Data) throws {
        let size = try data.readInteger()

        var keys: [Int] = []
        var keyIndex = try data.readInteger()
        while keyIndex != 0 {
            keys.append(keyIndex)
            keyIndex = try data.readInteger()
        }

        let header = try Header(data: &data)

        self.size = size
        self.subheader = header
        self.keys = keys
    }
}

extension RegularUnkeyedHeader {
    init(data: inout Data) throws {
        var sizes: [Int] = []
        var size = try data.readInteger()
        while size != 1 {
            sizes.append(size)
            size = try data.readInteger()
        }

        self.sizes = sizes
    }
}

extension EquisizedUnkeyedHeader {
    init(data: inout Data) throws {
        size = try data.readInteger()
    }
}

extension UniformUnkeyedHeader {
    init(data: inout Data) throws {
        size = try data.readInteger()
        count  = try data.readInteger()
        subheader = try Header(data: &data)
    }
}
