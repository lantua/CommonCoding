import XCTest
@testable import LNTBinaryCoding

final class BinaryCodingTests: XCTestCase {
    let encoder = BinaryEncoder(), decoder = BinaryDecoder()

    func testCodingPath() throws {
        struct A: Codable {
            init() { }
            init(from decoder: Decoder) throws {
                var path: [CodingKey]

                let container = try decoder.container(keyedBy: CodingKeys.self)
                path = container.codingPath
                XCTAssertTrue(path.isEmpty)

                do {
                    let decoder = try container.superDecoder(forKey: .a)
                    var container = try decoder.unkeyedContainer()
                    path = container.codingPath
                    XCTAssertEqual(path.map { $0.intValue }, [nil])
                    XCTAssertEqual(path.map { $0.stringValue }, ["a"])

                    do {
                        let decoder = try container.superDecoder()
                        let container = try decoder.singleValueContainer()
                        path = container.codingPath
                        XCTAssertEqual(path.map { $0.intValue }, [nil, 0])
                        XCTAssertEqual(path.map { $0.stringValue }, ["a", "0"])

                        path = decoder.codingPath
                        XCTAssertEqual(path.map { $0.intValue }, [nil, 0])
                        XCTAssertEqual(path.map { $0.stringValue }, ["a", "0"])

                        XCTAssertEqual(decoder.userInfo[CodingUserInfoKey(rawValue: "asdf")!] as? Int, 343)
                    }
                }
            }
            func encode(to encoder: Encoder) throws {
                var path: [CodingKey]

                var container = encoder.container(keyedBy: CodingKeys.self)
                path = container.codingPath
                XCTAssertTrue(path.isEmpty)

                do {
                    let encoder = container.superEncoder(forKey: .a)
                    var container = encoder.unkeyedContainer()
                    path = container.codingPath
                    XCTAssertEqual(path.map { $0.intValue }, [nil])
                    XCTAssertEqual(path.map { $0.stringValue }, ["a"])

                    do {
                        let encoder = container.superEncoder()
                        let container = encoder.singleValueContainer()
                        path = container.codingPath
                        XCTAssertEqual(path.map { $0.intValue }, [nil, 0])
                        XCTAssertEqual(path.map { $0.stringValue }, ["a", "0"])

                        path = encoder.codingPath
                        XCTAssertEqual(path.map { $0.intValue }, [nil, 0])
                        XCTAssertEqual(path.map { $0.stringValue }, ["a", "0"])

                        XCTAssertEqual(encoder.userInfo[CodingUserInfoKey(rawValue: "asdg")!] as? Int, 324)
                    }
                }
            }

            enum CodingKeys: CodingKey {
                case a
            }
        }

        var decoder = self.decoder, encoder = self.encoder
        decoder.userInfo[CodingUserInfoKey(rawValue: "asdf")!] = 343
        encoder.userInfo[CodingUserInfoKey(rawValue: "asdg")!] = 324
        _ = try decoder.decode(A.self, from: encoder.encode(A()))
    }

    func testSingleValueContainerRoundtrip() throws {
        // Delegated roundtrips
        try XCTAssertEqual(decoder.decode(Bool.self, from: encoder.encode(false)), false)
        try XCTAssertEqual(decoder.decode(Bool.self, from: encoder.encode(true)), true)
        try XCTAssertEqual(decoder.decode(Double?.self, from: encoder.encode(5.0 as Double?)), 5.0)
        try XCTAssertEqual(decoder.decode(Float.self, from: encoder.encode(4.2 as Float)), 4.2)

        // String roundtrips
        try XCTAssertEqual(decoder.decode(String.self, from: encoder.encode("ffah")), "ffah")

        // Signed roundtrips
        try XCTAssertEqual(decoder.decode(Int.self, from: encoder.encode(0x17)), 0x17)
        try XCTAssertEqual(decoder.decode(Int.self, from: encoder.encode(-0x1419)), -0x1419)
        try XCTAssertEqual(decoder.decode(Int.self, from: encoder.encode(-0x1919a077)), -0x1919a077)
        try XCTAssertEqual(decoder.decode(Int.self, from: encoder.encode(-0x19197fabd93bca07)), -0x19197fabd93bca07)

        // Unsigned roundtrips
        try XCTAssertEqual(decoder.decode(UInt.self, from: encoder.encode(0x17 as UInt)), 0x17)
        try XCTAssertEqual(decoder.decode(UInt.self, from: encoder.encode(0x1419 as UInt)), 0x1419)
        try XCTAssertEqual(decoder.decode(UInt.self, from: encoder.encode(0x19154977 as UInt)), 0x19154977)
        try XCTAssertEqual(decoder.decode(UInt.self, from: encoder.encode(0x19197fabd93bca07 as UInt)), 0x19197fabd93bca07)
    }

    func testUnkeyedContainerRoundtrip() throws {
        do {
            let value = [1, 2, 3, 4, nil, 5, 6, 7, 5, 3, 4, 5, 6]
            try XCTAssertEqual(decoder.decode([Int?].self, from: encoder.encode(value)), value)
        }

        do {
            let value: [Int?] = [nil, nil, nil, nil, nil, nil]
            try XCTAssertEqual(decoder.decode([Int?].self, from: encoder.encode(value)), value)
        }
        do {
            let value = (0..<128).map(String.init)
            try XCTAssertEqual(decoder.decode([String].self, from: encoder.encode(value)), value)
        }
    }

    func testKeyedContainerRoundtrip() {
        do {
            struct Test: Codable, Equatable {
                enum B: Int, Codable { case a, b, c }
                var a: String?, b: B, c: Int
            }

            let value = Test(a: "asdfhjjdn", b: .a, c: 994)
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(value)), value)
        }

        do {
            struct Test: Codable, Equatable { var a, b, c, d: Int }
            let value = Test(a: 1, b: 2, c: 3, d: 5)
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(value)), value)
        }
        do {
            struct Test: Codable, Equatable { var a, b, c, d, e: Int16, f: String }
            let value = Test(a: 1, b: 2, c: 3, d: 5, e: 2, f: "")
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(value)), value)
        }
        do {
            let value: [String: Int?] = ["a": 1, "b": nil]
            try XCTAssertEqual(decoder.decode([String: Int?].self, from: encoder.encode(value)), value)
        }
        do {
            struct A: Codable, Equatable { var a, b, c, d, e, f, g: Int? }
            try XCTAssertEqual(decoder.decode(A.self, from: encoder.encode(A())), A())
        }
    }

    func testDecoder() throws {
        try XCTAssertNil(decoder.decode(Int?.self, from: Data([0,0,0])))

        /// Keyed containers will picked latter values.
        try XCTAssertEqual(decoder.decode([String: Int8].self, from: Data(
            [0,0,
             1,Character("a").asciiValue!,0,
             Header.Tag.regularKeyed.rawValue, 2,1, 2,1, 0x1,
             1,0,
             2,1
        ])), ["a": 1])
        try XCTAssertEqual(decoder.decode([String: Int8].self, from: Data(
            [0,0,
             1,Character("a").asciiValue!,0,
             Header.Tag.equisizeKeyed.rawValue, 2, 1,1,0x0,
             1,0,
             2,1
        ])), ["a": 1])
        try XCTAssertEqual(decoder.decode([String: Int8].self, from: Data(
            [0,0,
             1,Character("a").asciiValue!,0,
             Header.Tag.uniformKeyed.rawValue, 2, 1,1,0x0, Header.Tag.signed.rawValue,
             2,
             1
        ])), ["a": 1])

        /// Uniform unkeyed container of `nil`
        do {
            let data = try encoder.encode(Array(repeating: nil as Int?, count: 10))

            struct A: Decodable {
                init(from decoder: Decoder) throws {
                    var container = try decoder.unkeyedContainer()
                    for _ in 0..<10 {
                        try XCTAssertTrue(container.decodeNil())
                        try XCTAssertNil(container.decode(Int?.self))
                    }
                }
            }

            try _ = decoder.decode(A.self, from: data)
        }
    }

    func testNestedKeyedContainer() throws {
        struct KeyedCodable: Codable, Equatable {
            var a: Float, b: String, c: Int, d: UInt

            init(_ values: (Float, String, Int, UInt)) { (a, b, c, d) = values }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                try XCTAssertFalse(container.decodeNil(forKey: .a))
                try XCTAssertTrue(container.decodeNil(forKey: .e))
                try XCTAssertTrue(container.decodeNil(forKey: .f))
                XCTAssertTrue(container.contains(.e))
                XCTAssertFalse(container.contains(.f))
                XCTAssertEqual(Set(container.allKeys), [.a, .b, .c, .e])

                do {
                    var nested = try container.nestedUnkeyedContainer(forKey: .a)
                    a = try nested.decode(Float.self)
                }
                b = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .b).decode(String.self, forKey: .a)
                c = try Int(from: container.superDecoder(forKey: .c))
                d = try UInt(from: container.superDecoder())
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                do {
                    var nested = container.nestedUnkeyedContainer(forKey: .a)
                    try nested.encode(a)
                }
                do {
                    var nested = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .b)
                    try nested.encode(b, forKey: .a)
                }
                try c.encode(to: container.superEncoder(forKey: .c))
                try d.encode(to: container.superEncoder())
                try container.encodeNil(forKey: .e)
            }

            enum CodingKeys: CodingKey, Equatable {
                case a, b, c, e, f
            }
            enum NestedCodingKeys: CodingKey {
                case a
            }
        }

        let values = KeyedCodable((0.0, "test", -33, 4))
        try XCTAssertEqual(decoder.decode(KeyedCodable.self, from: encoder.encode(values)), values)
    }

    func testNestedUnkeyedContainer() {
        struct UnkeyedCodable: Codable, Equatable {
            var a: Float, b: String, c: Int

            init(_ values: (Float, String, Int)) { (a, b, c) = values }

            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()

                try XCTAssertFalse(container.decodeNil())
                do {
                    var nested = try container.nestedUnkeyedContainer()
                    a = try nested.decode(Float.self)
                }
                b = try container.nestedContainer(keyedBy: NestedCodingKeys.self).decode(String.self, forKey: .a)
                c = try Int(from: container.superDecoder())
                try XCTAssertTrue(container.decodeNil())
                XCTAssertFalse(container.isAtEnd)
                try XCTAssertNil(container.decode(Bool?.self))

                XCTAssertTrue(container.isAtEnd)
                try XCTAssertTrue(container.decodeNil())
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                do {
                    var nested = container.nestedUnkeyedContainer()
                    try nested.encode(a)
                }
                do {
                    var nested = container.nestedContainer(keyedBy: NestedCodingKeys.self)
                    try nested.encode(b, forKey: .a)
                }
                try c.encode(to: container.superEncoder())
                try container.encodeNil()
            }

            enum NestedCodingKeys: CodingKey {
                case a
            }
        }

        let values = UnkeyedCodable((0.0, "test", -33))
        try XCTAssertEqual(decoder.decode(UnkeyedCodable.self, from: encoder.encode(values)), values)
    }

    func testStructuralError() {
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data())) // Empty file
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data([0,1]))) // Invalid version
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data([0,0,0x80]))) // Invalid String Map count
        try XCTAssertThrowsError(decoder.decode([Int].self, from: Data([0,0, 0, 0x0, 3,0x01,0]))) // Invalid Tag
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data([0,0, 1,0x80,0]))) // Invalid String
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data([0,0, 1,0x80]))) // Invalid String
    }

    func testSingleValueError() {
        // Container Too small
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data([0,0,0, Header.Tag.signed.rawValue])))
        try XCTAssertThrowsError(decoder.decode(UInt.self, from: Data([0,0,0, Header.Tag.unsigned.rawValue])))

        // Decoding from nil
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data([0,0,0,])))
        try XCTAssertThrowsError(decoder.decode(String.self, from: Data([0,0,0,])))

        do {
            // Past the end
            struct A: Codable {
                init() { }
                init(from decoder: Decoder) throws {
                    var container = try decoder.unkeyedContainer()
                    for _ in 0..<127 {
                        try XCTAssertNil(container.decode(Bool?.self))
                    }
                    try _ = container.decode(Bool?.self)
                }
                func encode(to encoder: Encoder) throws {
                    var container = encoder.unkeyedContainer()
                    for _ in 0..<127 {
                        try container.encodeNil()
                    }
                }
            }

            try XCTAssertThrowsError(decoder.decode(A.self, from: encoder.encode(A())))
        }
    }

    func testKeyedError() {
        let stringMapA: [UInt8] = [0,0, 1,Character("a").asciiValue!,0]

        // Container Too Small
        try XCTAssertThrowsError(decoder.decode([String: Int].self, from: Data(stringMapA + [Header.Tag.regularKeyed.rawValue,10,1,0x01, 00])))
        try XCTAssertThrowsError(decoder.decode([String: Int].self, from: Data(stringMapA + [Header.Tag.equisizeKeyed.rawValue,10,1,0x00, 00])))
        try XCTAssertThrowsError(decoder.decode([String: Int].self, from: Data(stringMapA + [Header.Tag.uniformKeyed.rawValue,10,0x01,1, 00])))

        // Invalid Element
        try XCTAssertThrowsError(decoder.decode([String: Int].self, from: Data(stringMapA + [Header.Tag.regularKeyed.rawValue,2,1,0x01, 0x00,0])))
        try XCTAssertThrowsError(decoder.decode([String: Int].self, from: Data(stringMapA + [Header.Tag.equisizeKeyed.rawValue,2,1,0x00, 0x00,0])))

        // Key not found
        do {
            struct A: Codable { var a, b: Int }
            struct B: Codable { var a = 0, c = "" }
            try XCTAssertThrowsError(decoder.decode(A.self, from: encoder.encode(B())))
        }
        // Key not found - Uniform
        do {
            struct A: Codable { var a = 0, b = 0, c = 0, d = 0, e = 0, f = 0 }
            struct B: Codable { var a = 0, b = 0, c = 0, d = 0, e = 0 }
            try XCTAssertThrowsError(decoder.decode(A.self, from: encoder.encode(B())))
        }
    }

    func testUnkeyedError() {
        // Container Too Small
        try XCTAssertThrowsError(decoder.decode([Int].self, from: Data([0,0,0, Header.Tag.regularUnkeyed.rawValue,2,2,0x1, 0])))
        try XCTAssertThrowsError(decoder.decode([Int].self, from: Data([0,0,0, Header.Tag.equisizeUnkeyed.rawValue,2,1])))
        try XCTAssertThrowsError(decoder.decode([Int].self, from: Data([0,0,0, Header.Tag.uniformUnkeyed.rawValue,2,2,1, 1])))

        // Invalid Element
        try XCTAssertThrowsError(decoder.decode([Int].self, from: Data([0,0,0, Header.Tag.regularUnkeyed.rawValue,2,2,0x1, 0,0,0,0])))
        try XCTAssertThrowsError(decoder.decode([Int].self, from: Data(
            [0,0,0, Header.Tag.equisizeUnkeyed.rawValue,2,1,
             Header.Tag.string.rawValue,0x80])))
        try XCTAssertThrowsError(decoder.decode([Int].self, from: Data(
            [0,0,0, Header.Tag.uniformUnkeyed.rawValue,2,2,
             Header.Tag.string.rawValue,0x80,0x80])))

        do {
            // Invalid element while `decodeNil`
            struct A: Decodable {
                init(from decoder: Decoder) throws {
                    var container = try decoder.unkeyedContainer()
                    _ = try container.decodeNil()
                }
            }

            try XCTAssertThrowsError(decoder.decode(A.self, from: Data(
                [0,0,0, Header.Tag.equisizeUnkeyed.rawValue,2,1,
                 0,0x80])))
        }
    }

    func testErrorWrongContainer() {
        // Value out of range
        try XCTAssertThrowsError(decoder.decode(Int.self, from: encoder.encode(UInt.max)))
        try XCTAssertThrowsError(decoder.decode(UInt.self, from: encoder.encode(-1)))

        // To String
        try XCTAssertThrowsError(decoder.decode(String.self, from: encoder.encode(0)))
        try XCTAssertThrowsError(decoder.decode(String.self, from: encoder.encode(0 as UInt)))
        try XCTAssertThrowsError(decoder.decode(String.self, from: Data([0,0,0, Header.Tag.string.rawValue,1])))

        // Requesting keyed, unkeyed, and single from different category.
        try XCTAssertThrowsError(decoder.decode([Int: String].self, from: encoder.encode([1, 2, 3])))
        try XCTAssertThrowsError(decoder.decode(Int.self, from: encoder.encode([1, 2, 3])))
        try XCTAssertThrowsError(decoder.decode([Int].self, from: encoder.encode(2)))
    }

    static var allTests = [
        ("testSingleValueContainerRoundtrip", testSingleValueContainerRoundtrip),
        ("testUnkeyedContainerRoundtrip", testUnkeyedContainerRoundtrip),
        ("testKeyedContainerRoundtrip", testKeyedContainerRoundtrip),

        ("testDecoder", testDecoder),

        ("testNestedKeyedContainer", testNestedKeyedContainer),
        ("testNestedUnkeyedContainer", testNestedUnkeyedContainer),

        ("testSingleValueError", testSingleValueError),
        ("testKeyedError", testKeyedError),
        ("testUnkeyedError", testUnkeyedError),
        ("testErrorWrongContainer", testErrorWrongContainer)
    ]
}

