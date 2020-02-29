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
        var size = try data.extractVSUI()
        while size != 1 {
            let key = try data.extractVSUI()
            mapping.append((key, size))

            size = try data.extractVSUI()
        }

        self.mapping = mapping
    }
}

extension EquisizeKeyedHeader {
    init(data: inout Data) throws {
        var keys: [Int] = []

        let size = try data.extractVSUI()
        var keyIndex = try data.extractVSUI()
        while keyIndex != 0 {
            keys.append(keyIndex)
            keyIndex = try data.extractVSUI()
        }

        self.size = size
        self.keys = keys
    }
}

extension UniformKeyedHeader {
    init(data: inout Data) throws {
        let itemSize = try data.extractVSUI()

        var keys: [Int] = []
        var keyIndex = try data.extractVSUI()
        while keyIndex != 0 {
            keys.append(keyIndex)
            keyIndex = try data.extractVSUI()
        }

        let header = try Header(data: &data)

        self.itemSize = itemSize
        self.subheader = header
        self.keys = keys
    }
}

extension RegularUnkeyedHeader {
    init(data: inout Data) throws {
        var sizes: [Int] = []
        var size = try data.extractVSUI()
        while size != 1 {
            sizes.append(size)
            size = try data.extractVSUI()
        }

        self.sizes = sizes
    }
}

extension EquisizedUnkeyedHeader {
    init(data: inout Data) throws {
        size = try data.extractVSUI()
        count = try data.extractVSUI()
    }
}

extension UniformUnkeyedHeader {
    init(data: inout Data) throws {
        itemSize = try data.extractVSUI()
        count  = try data.extractVSUI()
        subheader = try Header(data: &data)
    }
}
