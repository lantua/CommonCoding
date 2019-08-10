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

    func testSingleValueRoundtrip() throws {
        try XCTAssertEqual(decoder.decode(Bool.self, from: encoder.encode(false)), false)
        try XCTAssertEqual(decoder.decode(Bool.self, from: encoder.encode(true)), true)
        try XCTAssertEqual(decoder.decode(Double?.self, from: encoder.encode(5.0 as Double?)), 5.0)
        try XCTAssertEqual(decoder.decode(Float.self, from: encoder.encode(4.2 as Float)), 4.2)
        try XCTAssertEqual(decoder.decode(Int?.self, from: encoder.encode(-7)), -7)
        try XCTAssertEqual(decoder.decode(UInt.self, from: encoder.encode(5 as UInt)), 5)
    }

    func testUnkeyedValueRoundtrip() throws {
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
            let value = Test(b: true, ob: false, d: 3, f: 7, i: -9, u: 1, ii: 234)
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(value)), value)
        }
        do {
            let value = Test(b: false, ob: true, d: 2.3, f: 5, i: -11, u: 93, ii: 837)
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(value)), value)
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
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode([value])), value)
        }
    }

    func testError() {
        try XCTAssertThrowsError(decoder.decode(Int.self, from: Data()))
    }

    static var allTests = [
        ("testCodingKeys", testCodingKeys),

        ("testSingleValueRoundtrip", testSingleValueRoundtrip),
        ("testUnkeyedValueRoundtrip", testUnkeyedValueRoundtrip),

        ("testRoundtrip", testRoundtrip),
        ("testError", testError),
    ]
}

