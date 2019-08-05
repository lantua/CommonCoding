import XCTest
@testable import CSVCoder

final class CSVCoderTests: XCTestCase {
    let encoder = CSVEncoder(), decoder = CSVDecoder()

    func testEscaping() {
        // Non-escaping
        XCTAssertEqual("aall".escaped(separator: ",", forced: false), "aall") // Non-escaping

        // Escaping
        XCTAssertEqual("aa\"kj".escaped(separator: ",", forced: false), "\"aa\"\"kj\"") // Double quote
        XCTAssertEqual("aa\njj".escaped(separator: ",", forced: false), "\"aa\njj\"") // \n
        XCTAssertEqual("\u{11}".escaped(separator: ",", forced: false), "\"\u{11}\"") // Non-printable
        XCTAssertEqual("🧐".escaped(separator: ",", forced: false), "\"🧐\"") // Non-ascii
        XCTAssertEqual("asjk".escaped(separator: ",", forced: true), "\"asjk\"") // Forced
    }

    func testTokenizer() {
        do {
            let value = """
            a,"l",,""

            "llk""d",jjkk
            ,
            """
            let tokens = UnescapedCSVTokens(base: value, separator: ",")
            var iterator = tokens.makeIterator()
            XCTAssertEqual(iterator.next(), .unescaped("a"))
            XCTAssertEqual(iterator.next(), .escaped("l"))
            XCTAssertEqual(iterator.next(), .unescaped(""))
            XCTAssertEqual(iterator.next(), .escaped(""))
            XCTAssertEqual(iterator.next(), .rowBoundary)

            XCTAssertEqual(iterator.next(), .unescaped(""))
            XCTAssertEqual(iterator.next(), .rowBoundary)

            XCTAssertEqual(iterator.next(), .escaped("llk\"d"))
            XCTAssertEqual(iterator.next(), .unescaped("jjkk"))
            XCTAssertEqual(iterator.next(), .rowBoundary)

            XCTAssertEqual(iterator.next(), .unescaped(""))
            XCTAssertEqual(iterator.next(), .unescaped(""))
            XCTAssertEqual(iterator.next(), .rowBoundary)

            XCTAssertNil(iterator.next())
            XCTAssertNil(iterator.next())
        }
        do {
            let value = "\"ghghg\""
            let tokens = UnescapedCSVTokens(base: value, separator: ",")
            var iterator = tokens.makeIterator()

            XCTAssertEqual(iterator.next(), .escaped("ghghg"))
            XCTAssertEqual(iterator.next(), .rowBoundary)

            XCTAssertNil(iterator.next())
            XCTAssertNil(iterator.next())
        }
        do {
            let value = "ghghg"
            let tokens = UnescapedCSVTokens(base: value, separator: ",")
            var iterator = tokens.makeIterator()

            XCTAssertEqual(iterator.next(), .unescaped("ghghg"))
            XCTAssertEqual(iterator.next(), .rowBoundary)

            XCTAssertNil(iterator.next())
            XCTAssertNil(iterator.next())
        }
        do {
            let value = """
            a,l,alskl",asd\n
            """
            let tokens = UnescapedCSVTokens(base: value, separator: ",")
            var iterator = tokens.makeIterator()

            XCTAssertEqual(iterator.next(), .unescaped("a"))
            XCTAssertEqual(iterator.next(), .unescaped("l"))
            XCTAssertEqual(iterator.next(), .invalid(.unescapedQuote))

            XCTAssertNil(iterator.next())
            XCTAssertNil(iterator.next())
        }
        do {
            let value = """
            "a\"k\n
            """
            let tokens = UnescapedCSVTokens(base: value, separator: ",")
            var iterator = tokens.makeIterator()

            XCTAssertEqual(iterator.next(), .invalid(.invalidEscaping("k")))

            XCTAssertNil(iterator.next())
            XCTAssertNil(iterator.next())
        }
        do {
            let value = """
            "a\""hjhu\n
            """
            let tokens = UnescapedCSVTokens(base: value, separator: ",")
            var iterator = tokens.makeIterator()

            XCTAssertEqual(iterator.next(), .invalid(.unclosedQoute))

            XCTAssertNil(iterator.next())
            XCTAssertNil(iterator.next())
        }
    }

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
        }
    }

    func testRoundtrip() {
        do {
            let value1: Int? = nil
            let encoder = CSVEncoder(options: .useNullasNil)
            let decoder = CSVDecoder(options: .treatNullAsNil)
            try XCTAssertEqual(decoder.decode(Int?.self, from: encoder.encode([value1])), [value1])

            let value2 = "null"
            try XCTAssertEqual(decoder.decode(String?.self, from: encoder.encode([value2])), [value2])
        }
        do {
            struct Test: Codable, Equatable {
                var value: String

                init(_ value: String) {
                    self.value = value
                }

                init(from decoder: Decoder) throws {
                    XCTAssertEqual(decoder.userInfo[CodingUserInfoKey(rawValue: "decodingKey")!] as? String, "decodingValue")
                    value = try String(from: decoder)
                }

                func encode(to encoder: Encoder) throws {
                    XCTAssertEqual(encoder.userInfo[CodingUserInfoKey(rawValue: "encodingKey")!] as? String, "encodingValue")
                    try value.encode(to: encoder)
                }
            }
            let encoder = CSVEncoder(userInfo: [CodingUserInfoKey(rawValue: "encodingKey")! : "encodingValue"])
            let decoder = CSVDecoder(userInfo: [CodingUserInfoKey(rawValue: "decodingKey")! : "decodingValue"])
            let value = Test("some string")
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode([value])), [value])
        }
    }

    func testSingleRoundtrip() throws {
        let values = [144, nil]
        try XCTAssertEqual(decoder.decode(Int?.self, from: encoder.encode(values)), values)
    }

    func testKeyedRoundtrip() throws {
        do {
            struct Test: Codable, Equatable {
                var a: Int, b: [String]
            }
            let values = [Test(a: 1, b: ["foo"]), Test(a: 77, b: ["bar"])]
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(values)), values)
        }
        do {
            struct Test: Codable, Equatable {
                var b: Bool?, d: Double?, f: Float?
                var i:  Int?, i8:  Int8?, i16:  Int16?, i32:  Int32?, i64:  Int64?
                var u: UInt?, u8: UInt8?, u16: UInt16?, u32: UInt32?, u64: UInt64?
            }
            let values = [
                Test(b: true, d: 0.2, f: 0.2, i: nil, i8: 9, i16: 77, i32: nil, i64: -737, u: 87, u8: 77, u16: 37, u32: 7874, u64: 737333)
            ]
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(values)), values)
        }
    }

    func testUnkeyedRoundtrip() throws {
        do {
            let values = [[1, 2, 3], [1, nil, 9], []]
            try XCTAssertEqual(decoder.decode([Int?].self, from: encoder.encode(values)), values)
        }

        do {
            let values = [["sst", "jkj", "uuy"], ["uuh", nil], [nil, nil, nil, nil]]
            let expected: [[String?]] = values.map { array in
                guard let index = array.lastIndex(where: { $0 != nil }) else {
                    return []
                }
                return Array(array.prefix(through: index))
            }
            try XCTAssertEqual(decoder.decode([String?].self, from: encoder.encode(values)), expected)
        }

        do { // Statically call decode(_:), decodeIfPresent(_:)
            struct Test: Codable, Equatable {
                var s: String, b: Bool?, c: Int?

                init(s: String, b: Bool?) {
                    self.s = s
                    self.b = b
                }

                init(from decoder: Decoder) throws {
                    var container = try decoder.unkeyedContainer()
                    b = try container.decodeIfPresent(Bool.self)
                    s = try container.decode(String.self)
                    c = try container.decode(Int?.self)
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.unkeyedContainer()
                    try container.encode(b)
                    try container.encode(s)
                    try container.encodeNil()
                }
            }

            let values = [Test(s: "Something", b: false), Test(s: "lld", b: nil)]
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(values)), values)
        }
    }

    func testBehaviours() throws {
        do { // Interesting interaction between Dictionary and Array
            let dictionary = [1: "test", 3: "some"]
            let array = [nil, "test", nil, "some"]

            try XCTAssertEqual(decoder.decode([Int: String].self, from: encoder.encode([dictionary])), [dictionary])
            try XCTAssertEqual(decoder.decode([Int: String].self, from: encoder.encode([array])), [dictionary])
            try XCTAssertEqual(decoder.decode([String?].self, from: encoder.encode([dictionary])), [array])
            try XCTAssertEqual(decoder.decode([String?].self, from: encoder.encode([array])), [array])
        }

        do {
            struct Test: Encodable {
                var duplicatedValue: String? = nil, addExtraKey = false

                init(duplicatedValue: String? = nil, addExtraKey: Bool = false) {
                    self.duplicatedValue = duplicatedValue
                    self.addExtraKey = addExtraKey
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode("Test", forKey: .a)

                    if let value = duplicatedValue {
                        try container.encode(value, forKey: .a)
                    }
                    if addExtraKey {
                        try container.encode("Value", forKey: .b)
                    }
                }

                enum CodingKeys: CodingKey {
                    case a, b
                }
            }

            // Unconstrained duplicated keys
            try XCTAssertThrowsError(encoder.encode([Test(duplicatedValue: "Some value")]))
            // Constrained duplicated keys
            try XCTAssertThrowsError(encoder.encode([Test(), Test(duplicatedValue: "Other value")]))

            // Unconstrained duplicated keys with same value
            try XCTAssertNoThrow(encoder.encode([Test(duplicatedValue: "Test")]))
            // Constrained duplicated keys with same value
            try XCTAssertNoThrow(encoder.encode([Test(), Test(duplicatedValue: "Test")]))

            // Added extra key in constrained variable
            try XCTAssertThrowsError(encoder.encode([Test(), Test(addExtraKey: true)]))
        }

        do {
            struct BadDecoder: Decodable {
                init(from decoder: Decoder) throws {
                    var container = try decoder.unkeyedContainer()
                    _ = try container.decode(Bool.self)
                    _ = try container.decode(Int.self)
                    _ = try container.decodeIfPresent(Bool.self)
                }
            }
            // Decode more than what unkeyed container has
            try XCTAssertNoThrow(decoder.decode(BadDecoder.self, from: "0,1,2\ntrue,0,"))
            try XCTAssertNoThrow(decoder.decode(BadDecoder.self, from: "0,1\ntrue,0"))
            try XCTAssertThrowsError(decoder.decode(BadDecoder.self, from: "0\ntrue"))
        }
        do {
            struct Test: Decodable {
                var s: String?, b: Bool
            }

            try XCTAssertThrowsError(decoder.decode(Test.self, from: "s,g\nkjk,ll")) // Key not found
            try XCTAssertThrowsError(decoder.decode(Test.self, from: "s,b\nsomeString,")) // Value not found
            try XCTAssertThrowsError(decoder.decode(Test.self, from: "s.1,s.3,b\n4,ll,true")) // Multi-field as simple object
            try XCTAssertThrowsError(decoder.decode(Test.self, from: "s,b\nsdff,0.5")) // Type mismatch
        }
        do {
            try XCTAssertThrowsError(decoder.decode(Int.self, from: "\n1\n7,")) // Unequal rows
            try XCTAssertThrowsError(decoder.decode(Int.self, from: "b,a,a,d\n,,,")) // Duplicated field `a`
            try XCTAssertThrowsError(decoder.decode(Int.self, from: "b,,,d\n,,,")) // Duplicated field ``
            try XCTAssertThrowsError(decoder.decode(Int.self, from: "\"")) // Invalid CSV
        }
    }

    func testDecoding() throws {
        try XCTAssertEqual(decoder.decode([Int?].self, from: "0,2\n\"1\",2"), [[1, nil, 2]])
        do {
            struct Test: Decodable, Equatable {
                var a: Int?, b: Int?, c: Int?

                init(a: Int?, b: Int?, c: Int?) {
                    self.a = a
                    self.b = b
                    self.c = c
                }

                init(from decoder: Decoder) throws {
                    var container = try decoder.unkeyedContainer()
                    a = try container.decodeIfPresent(Int.self)
                    b = try container.decodeIfPresent(Int.self)
                    c = try container.decodeIfPresent(Int.self)
                }
            }
            try XCTAssertEqual(decoder.decode(Test.self, from: "0,2\n1,2"), [Test(a: 1, b: nil, c: 2)])
        }
    }
    
    func testNestedKeyedContainers() throws {
        struct KeyedCodable: Codable, Equatable {
            var a: Float, b: String, c: Int, d: Double

            init(a: Float, b: String, c: Int, d: Double) {
                self.a = a
                self.b = b
                self.c = c
                self.d = d
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                do {
                    var nested = try container.nestedUnkeyedContainer(forKey: .a)
                    a = try nested.decode(Float.self)
                }
                b = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .b).decode(String.self, forKey: .a)
                c = try Int(from: container.superDecoder(forKey: .c))
                d = try Double(from: container.superDecoder())
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
            }

            enum CodingKeys: CodingKey {
                case a, b, c, d
            }
            enum NestedCodingKeys: CodingKey {
                case a
            }
        }

        let values = KeyedCodable(a: 0.0, b: "test", c: -33, d: .infinity)
        try XCTAssertEqual(decoder.decode(KeyedCodable.self, from: encoder.encode([values])), [values])
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
        try XCTAssertEqual(decoder.decode(UnkeyedCodable.self, from: encoder.encode([values])), [values])
    }

    static var allTests = [
        ("testEscaping", testEscaping),
        ("testTokenizer", testTokenizer),
        ("testCodingKeys", testCodingKeys),
        ("testRoundtrip", testRoundtrip),

        ("testSingleRoundtrip", testSingleRoundtrip),
        ("testKeyedRoundtrip", testKeyedRoundtrip),
        ("testUnkeyedRoundtrip", testUnkeyedRoundtrip),

        ("testBehaviours", testBehaviours),
        ("testDecoding", testDecoding),

        ("testNestedKeyedContainers", testNestedKeyedContainers),
        ("testNestedUnkeyedContainer", testNestedUnkeyedContainer),
    ]
}

extension UnescapedCSVTokens.Token: Equatable {
    public static func == (lhs: UnescapedCSVTokens<S>.Token, rhs: UnescapedCSVTokens<S>.Token) -> Bool {
        switch (lhs, rhs) {
        case let (.escaped(l), .escaped(r)) where l == r,
             let (.unescaped(l), .unescaped(r)) where l == r:
            return true
        case let (.invalid(l), .invalid(r)):
            switch (l, r) {
            case (.unclosedQoute, .unclosedQoute),
                 (.unescapedQuote, .unescapedQuote):
                return true
            case let (.invalidEscaping(lc), .invalidEscaping(rc)) where lc == rc:
                return true
            default: return false
            }
        case (.rowBoundary, .rowBoundary):
            return true
        default: return false
        }
    }
}
