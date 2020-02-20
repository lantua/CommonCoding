import XCTest
@testable import LNTBinaryCoder

final class BinaryCoderTests: XCTestCase {
    let encoder = BinaryEncoder(), decoder = BinaryDecoder()

    func testCodingKeys() {
        do {
            let key1: CodingKey = UnkeyedCodingKey(intValue: 9988)
            XCTAssertEqual(key1.intValue, 9988)
            XCTAssertEqual(key1.stringValue, "9988")

            let key2: CodingKey? = UnkeyedCodingKey(stringValue: "someValue")
            XCTAssertNil(key2)

            let key3: CodingKey? = UnkeyedCodingKey(stringValue: "1234")
            XCTAssertEqual(key3?.intValue, 1234)
            XCTAssertEqual(key3?.stringValue, "1234")
        }

        do {
            let key1: CodingKey? = SuperCodingKey(intValue: 1)
            XCTAssertNil(key1)

            let key2: CodingKey? = SuperCodingKey(intValue: 0)
            XCTAssertEqual(key2?.intValue, 0)
            XCTAssertEqual(key2?.stringValue, "super")

            let key3: CodingKey? = SuperCodingKey(stringValue: "super")
            XCTAssertEqual(key3?.intValue, 0)
            XCTAssertEqual(key3?.stringValue, "super")

            let key4: CodingKey? = SuperCodingKey(stringValue: "Something else")
            XCTAssertNil(key4)

            let key5: CodingKey? = SuperCodingKey()
            XCTAssertEqual(key5?.intValue, 0)
            XCTAssertEqual(key5?.stringValue, "super")
        }
    }

    func testSingleValueContainerRoundtrip() throws {
        try XCTAssertEqual(decoder.decode(Bool.self, from: encoder.encode(false)), false)
        try XCTAssertEqual(decoder.decode(Bool.self, from: encoder.encode(true)), true)
        try XCTAssertEqual(decoder.decode(Double?.self, from: encoder.encode(5.0 as Double?)), 5.0)
        try XCTAssertEqual(decoder.decode(Float.self, from: encoder.encode(4.2 as Float)), 4.2)
        try XCTAssertEqual(decoder.decode(Int?.self, from: encoder.encode(-7)), -7)
        try XCTAssertEqual(decoder.decode(UInt.self, from: encoder.encode(5 as UInt)), 5)
        try XCTAssertEqual(decoder.decode(String.self, from: encoder.encode("ffah")), "ffah")
    }

    func testUnkeyedContainerRoundtrip() throws {
        struct Test: Codable, Equatable {
            var b: Bool, ob: Bool?, d: Double, f: Float, i: Int, u: UInt, ii: Int?

            init(b: Bool, ob: Bool?, d: Double, f: Float, i: Int, u: UInt, ii: Int?) {
                self.b = b
                self.ob = ob
                self.d = d
                self.f = f
                self.i = i
                self.u = u
                self.ii = ii
            }

            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                b = try container.decode(Bool.self)
                d = try container.decode(Double.self)
                f = try container.decode(Float.self)
                ii = try container.decode(Int?.self)
                try XCTAssertFalse(container.decodeNil())
                do {
                    let decoder = try container.superDecoder()
                    ob = try .init(from: decoder)
                }
                do {
                    var container = try container.nestedUnkeyedContainer()
                    i = try container.decode(Int.self)
                    u = try container.decode(UInt.self)
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode(b)
                try container.encode(d)
                try container.encode(f)
                try container.encode(ii)
                do {
                    let encoder = container.superEncoder()
                    try ob.encode(to: encoder)
                }
                do {
                    var container = container.nestedUnkeyedContainer()
                    try container.encode(i)
                    try container.encode(u)
                }
            }
        }
        do {
            let value = Test(b: true, ob: false, d: 3, f: 7, i: -9, u: 1, ii: nil)
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(value)), value)
        }
        do {
            let value = Test(b: false, ob: true, d: 2.3, f: 5, i: -11, u: 93, ii: 837)
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(value)), value)
        }

        do {
            let value = [1, 2, 3, 4, nil, 5, 6, 7, 5, 3, 4, 5, 6]
            try XCTAssertEqual(decoder.decode([Int?].self, from: encoder.encode(value)), value)
        }

        do {
            let value: [Int?] = [nil, nil, nil, nil, nil, nil]
            try XCTAssertEqual(decoder.decode([Int?].self, from: encoder.encode(value)), value)
        }
    }

    func testKeyedContainerRoundtrip() {
        do {
            struct Test: Codable, Equatable {
                enum B: Int, Codable {
                    case a, b, c
                }
                var a: String?, b: B, c: Int
            }

            let value = Test(a: "asdfhjjdn", b: .a, c: 994)
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(value)), value)
        }

        do {
            struct Test: Codable, Equatable {
                var a: Int, b: Int, c: Int, d: Int
            }

            let value = Test(a: 1, b: 2, c: 3, d: 5)
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(value)), value)
        }

        do {
            struct Test: Codable, Equatable {
                var a: Int16, b: Int16, c: Int16, d: Int16, e: Int16, f: String
            }

            let value = Test(a: 1, b: 2, c: 3, d: 5, e: 2, f: "")
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(value)), value)
        }

        do {
            let value: [String: Int?] = ["a": 1, "b": nil]
            try XCTAssertEqual(decoder.decode([String: Int?].self, from: encoder.encode(value)), value)
        }

        do {
            class Test: Codable { }
            final class Derived: Test {
                var a: Int

                init(a: Int) {
                    self.a = a
                    super.init()
                }

                required init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    a = try container.decode(Int.self, forKey: .a)
                    try super.init(from: container.superDecoder())
                }
                override func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(a, forKey: .a)
                    try super.encode(to: container.superEncoder())
                }

                enum CodingKeys: CodingKey { case a }
            }

            try XCTAssertEqual(decoder.decode(Derived.self, from: encoder.encode(Derived(a: 33))).a, 33)
        }
    }

    func testRoundtrip() throws {
        do {
            struct Test: Codable, Equatable {
                var value: Int

                init(_ value: Int) {
                    self.value = value
                }

                init(from decoder: Decoder) throws {
                    XCTAssertEqual(decoder.userInfo[CodingUserInfoKey(rawValue: "decodingKey")!] as? String, "decodingValue")
                    value = try Int(from: decoder)
                }

                func encode(to encoder: Encoder) throws {
                    XCTAssertEqual(encoder.userInfo[CodingUserInfoKey(rawValue: "encodingKey")!] as? String, "encodingValue")
                    try value.encode(to: encoder)
                }
            }
            let encoder = BinaryEncoder(userInfo: [CodingUserInfoKey(rawValue: "encodingKey")! : "encodingValue"])
            let decoder = BinaryDecoder(userInfo: [CodingUserInfoKey(rawValue: "decodingKey")! : "decodingValue"])
            let value = Test(776)
            try XCTAssertEqual(decoder.decode([Test].self, from: encoder.encode([value])), [value])
        }
    }
    
    func testDecoder() throws {
        try XCTAssertNil(decoder.decode(Int?.self, from: Data([0,0,0])))

        /// Keyed containers will picked latter values.
        try XCTAssertEqual(decoder.decode([String: Int8].self, from: Data([0,0,1,0x61,0, 0x10,2,1,2,1,0x1, 1,0, 2,1])), ["a": 1])
        try XCTAssertEqual(decoder.decode([String: Int8].self, from: Data([0,0,1,0x61,0, 0x11,2,1,1,0x0, 1,0, 2,1])), ["a": 1])
        try XCTAssertEqual(decoder.decode([String: Int8].self, from: Data([0,0,1,0x61,0, 0x12,2,2,1,1,0x0, 2,1])), ["a": 1])

    }

    func testNestedKeyedContainers() throws {
        struct KeyedCodable: Codable, Equatable {
            var a: Float, b: String, c: Int

            init(a: Float, b: String, c: Int) {
                self.a = a
                self.b = b
                self.c = c
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                do {
                    var nested = try container.nestedUnkeyedContainer(forKey: .a)
                    a = try nested.decode(Float.self)
                }
                b = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .b).decode(String.self, forKey: .a)
                c = try Int(from: container.superDecoder(forKey: .c))
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
            }

            enum CodingKeys: CodingKey {
                case a, b, c
            }
            enum NestedCodingKeys: CodingKey {
                case a
            }
        }

        let values = KeyedCodable(a: 0.0, b: "test", c: -33)
        try XCTAssertEqual(decoder.decode(KeyedCodable.self, from: encoder.encode(values)), values)
    }

    func testNestedUnkeyedContainer() {
        struct UnkeyedCodable: Codable, Equatable {
            var a: Float, b: String, c: Int

            init(a: Float, b: String, c: Int) {
                self.a = a
                self.b = b
                self.c = c
            }

            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                do {
                    var nested = try container.nestedUnkeyedContainer()
                    a = try nested.decode(Float.self)
                }
                b = try container.nestedContainer(keyedBy: NestedCodingKeys.self).decode(String.self, forKey: .a)
                c = try Int(from: container.superDecoder())
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
            }

            enum NestedCodingKeys: CodingKey {
                case a
            }
        }

        let values = UnkeyedCodable(a: 0.0, b: "test", c: -33)
        try XCTAssertEqual(decoder.decode(UnkeyedCodable.self, from: encoder.encode(values)), values)
    }


    func testError() {
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data())) // Empty file
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data([0,1]))) // Invalid version
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data([0,0,0x80]))) // Invalid String Map count
        try XCTAssertThrowsError(decoder.decode([Int].self, from: Data([0,0,0, 0x0,3,0x01,0]))) // Invalid Tag
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data([0,0,1, 0x80,0]))) // Invalid String
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data([0,0,1, 0x80]))) // Invalid String


        do {
            // Single

            // Container Too small
            try XCTAssertThrowsError(decoder.decode(Int.self, from: Data([0,0,0, 0x02,0,0,0,0])))

            // Invalid String
            try XCTAssertThrowsError(decoder.decode(String.self, from: Data([0,0,0, 0x02,0,0,0,0,0,0,0,0])))
            try XCTAssertThrowsError(decoder.decode(String.self, from: Data([0,0,0, 0x03,1])))

            // Decoding from nil
            try XCTAssertThrowsError(decoder.decode(Int.self, from: Data([0,0,0,])))
            try XCTAssertThrowsError(decoder.decode(String.self, from: Data([0,0,0,])))
        }

        do {
            // Keyed

            // Container Too Small
            try XCTAssertThrowsError(decoder.decode([String: Int].self, from: Data([0,0,1,0x61,0, 0x10,10,1,0x01, 00])))
            try XCTAssertThrowsError(decoder.decode([String: Int].self, from: Data([0,0,1,0x61,0, 0x11,10,1,0x00, 00])))
            try XCTAssertThrowsError(decoder.decode([String: Int].self, from: Data([0,0,1,0x61,0, 0x12,10,1,0x01, 00])))

            // Invalid Element
            try XCTAssertThrowsError(decoder.decode([String: Int].self, from: Data([0,0,1,0x61,0, 0x10,2,1,0x01, 0x00,0])))
            try XCTAssertThrowsError(decoder.decode([String: Int].self, from: Data([0,0,1,0x61,0, 0x11,2,1,0x00, 0x00,0])))

            // Key not found
            do {
                struct A: Codable { var a, b: Int }
                struct B: Codable { var a: Int }
                try XCTAssertThrowsError(decoder.decode(A.self, from: encoder.encode(B(a: 4))))
            }
        }

        do {
            // Unkeyed

            // Container Too Small
            try XCTAssertThrowsError(decoder.decode([Int].self, from: Data([0,0,0, 0x20,2,2,0x1, 0])))
            try XCTAssertThrowsError(decoder.decode([Int].self, from: Data([0,0,0, 0x21,2, 1])))
            try XCTAssertThrowsError(decoder.decode([Int].self, from: Data([0,0,0, 0x22,2,2,2, 1])))

            // Invalid Element
            try XCTAssertThrowsError(decoder.decode([Int].self, from: Data([0,0,0, 0x20,2,2,0x1, 0,0,0,0])))
            try XCTAssertThrowsError(decoder.decode([Int].self, from: Data([0,0,0, 0x21,2, 3,0x80,0])))
            try XCTAssertThrowsError(decoder.decode([Int].self, from: Data([0,0,0, 0x22,2,3,2, 0x80,0x80])))
        }

        do {
            // Wrong Container
            try XCTAssertThrowsError(decoder.decode([Int].self, from: encoder.encode([2: 3])))
            try XCTAssertThrowsError(decoder.decode([Int: Int].self, from: encoder.encode(3)))
        }

        do {
            // Encoder
            try XCTAssertThrowsError(decoder.decode([Int: String].self, from: encoder.encode([1, 2, 3])))
            try XCTAssertThrowsError(decoder.decode(Int.self, from: encoder.encode([1, 2, 3])))
            try XCTAssertThrowsError(decoder.decode([Int].self, from: encoder.encode(2)))
        }
    }

    static var allTests = [
        ("testCodingKeys", testCodingKeys),

        ("testSingleValueContainerRoundtrip", testSingleValueContainerRoundtrip),
        ("testUnkeyedContainerRoundtrip", testUnkeyedContainerRoundtrip),
        ("testKeyedContainerRoundtrip", testKeyedContainerRoundtrip),

        ("testRoundtrip", testRoundtrip),
        ("testDecoder", testDecoder),

        ("testNestedKeyedContainers", testNestedKeyedContainers),
        ("testNestedUnkeyedContainer", testNestedUnkeyedContainer),

        ("testError", testError),
    ]
}

