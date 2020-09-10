//
//  KeyedOptimizer.swift
//  
//
//  Created by Natchanon Luangsomboon on 20/2/2563 BE.
//

import Foundation

struct KeyedOptimizer: EncodingOptimizer {
    private var values: [String: EncodingOptimizer]

    var header = Header.nil
    private(set) var payloadSize = 0

    init(values: [String: EncodingOptimizer]) {
        self.values = values
    }

    mutating func optimize(for context: OptimizationContext) {
        for key in values.keys {
            values[key]!.optimize(for: context)
        }

        let keys = values.keys.map { context.index(for: $0) }

        var bestOption = regularSize(keys: keys)
        var bestSize = bestOption.header.size + bestOption.payload

        func compare(candidate: (header: Header, payload: Int)) {
            let candidateSize = candidate.header.size + candidate.payload
            if candidateSize <= bestSize {
                bestOption = candidate
                bestSize = candidateSize
            }
        }

        if !values.isEmpty {
            compare(candidate: equisizeSize(keys: keys))
        }

        if let candidate = uniformSize(keys: keys) {
            compare(candidate: candidate)
        }

        (header, payloadSize) = bestOption
    }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) {
        assert(data.count >= payloadSize)

        var data = data

        switch header {
        case let .regularKeyed(header):
            let mapping = header.mapping
            for (value, map) in zip(values.values, mapping) {
                let size = map.size
                value.write(to: data.prefix(size))
                data.removeFirst(size)
            }
        case let .equisizeKeyed(header):
            let size = header.payloadSize
            for value in values.values {
                if header.subheader != nil {
                    value.writePayload(to: data.prefix(size))
                } else {
                    value.write(to: data.prefix(size))
                }
                data.removeFirst(size)
            }
        default: fatalError("Unreachable")
        }
    }
}

private extension KeyedOptimizer {
    func regularSize(keys: [Int]) -> (header: Header, payload: Int) {
        let header = Header.regularKeyed(.init(mapping: .init(zip(keys, values.values.lazy.map { $0.size }))))
        return (header, values.values.lazy.map { $0.size }.reduce(0, +))
    }

    func equisizeSize(keys: [Int]) -> (header: Header, payload: Int) {
        let maxSize = values.values.map { $0.size }.reduce(0, max)
        return (.equisizeKeyed(.init(itemSize: maxSize, subheader: nil, keys: keys)), maxSize * keys.count)
    }

    func uniformSize(keys: [Int]) -> (header: Header, payload: Int)? {
        guard let (elementSize, subheader) = uniformize(values: values.values) else {
            return nil
        }

        return (.equisizeKeyed(.init(itemSize: elementSize, subheader: subheader, keys: keys)), (elementSize - subheader.size) * keys.count)
    }
}
