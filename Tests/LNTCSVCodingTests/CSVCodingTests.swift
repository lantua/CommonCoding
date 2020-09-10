import XCTest
@testable import LNTCSVCoding

final class CSVCodingTests: XCTestCase {
    let encoder = CSVEncoder(), decoder = CSVDecoder()

    func testEscaping() {
        // Non-escaping
        XCTAssertEqual("aall".escaped(separator: ",", forced: false), "aall") // Non-escaping

        // Escaping
        XCTAssertEqual("\"".escaped(separator: ",", forced: false), "\"\"\"\"") // Double quote
        XCTAssertEqual("aa\njj".escaped(separator: ",", forced: false), "\"aa\njj\"") // \n
        XCTAssertEqual("🧐".escaped(separator: ",", forced: false), "\"🧐\"") // Non-ascii
        XCTAssertEqual("abc".escaped(separator: ",", forced: true), "\"abc\"") // Forced
    }

    func testTokenizer() {
        do {
            let value = """
            a,"b",,""

            "llk""d"
            a
            """
            let tokens = Tokens(base: value)
            XCTAssertEqual(Array(tokens), [
                .unescaped("a"), .escaped("b"), .unescaped(""), .escaped(""), .rowBoundary,
                .unescaped(""), .rowBoundary,
                .escaped("llk\"d"), .rowBoundary,
                .unescaped("a"), .rowBoundary
            ])
        }
        do {
            let value = "\"test\""
            let tokens = Tokens(base: value)
            XCTAssertEqual(Array(tokens), [
                .escaped("test"), .rowBoundary
            ])
        }
        do {
            let value = """
            a,b,bad",
            """
            let tokens = Tokens(base: value)
            XCTAssertEqual(Array(tokens), [
                .unescaped("a"), .unescaped("b"), .invalid(.unescapedQuote)
            ])
        }
        do {
            let value = #""a\"k""#
            let tokens = Tokens(base: value)
            XCTAssertEqual(Array(tokens), [
                .invalid(.invalidEscaping("k"))
            ])
        }
        do {
            let value = #""un""closed"#
            let tokens = Tokens(base: value)
            XCTAssertEqual(Array(tokens), [
                .invalid(.unclosedQoute)
            ])
        }
    }

    func testRoundtrip() {
        do {
            let value1: Int? = nil
            let encoder = CSVEncoder(options: .useNullAsNil)
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

    func testSingleValueRoundtrip() throws {
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
                Test(b: true, d: 0.2, f: 0.2, i8: 9, i64: -737, u: 87, u16: 37, u32: 7874)
            ]
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(values)), values)
        }
        do {
            let values = [["a": 1, "b": 2], ["a": 3]]
            try XCTAssertEqual(decoder.decode([String: Int].self, from: encoder.encode(values)), values)
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
                    s = try container.decode(String.self)
                    b = try container.decodeIfPresent(Bool.self)
                    c = try container.decode(Int?.self)
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.unkeyedContainer()
                    try container.encode(s)
                    try container.encode(b)
                    try container.encodeNil()
                }
            }

            let values = [Test(s: "Something", b: false), Test(s: "lld", b: nil)]
            try XCTAssertEqual(decoder.decode(Test.self, from: encoder.encode(values)), values)
        }
    }

    func testBehaviours() throws {
        do {
            try XCTAssertEqual(decoder.decode(Int.self, from: "\n1\n2\n3\n"), [1, 2, 3])
        }
        do { // Interesting interaction between Dictionary and Array
            let dictionary = [0: "test", 3: "some"]
            let array = ["test", nil, nil, "some"]

            try XCTAssertEqual(decoder.decode([Int: String].self, from: encoder.encode([dictionary])), [dictionary])
            try XCTAssertEqual(decoder.decode([Int: String].self, from: encoder.encode([array])), [dictionary])
            try XCTAssertEqual(decoder.decode([String?].self, from: encoder.encode([dictionary])), [["test"]])
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
            try XCTAssertThrowsError(decoder.decode(Test.self, from: "s,s.1,s.3,b\n883,4,ll,true")) // Mixed multi/single field
        }
        do {
            struct Test: Decodable, Equatable {
                var a: [Int?], d: [Int: String]
            }
            try XCTAssertThrowsError(decoder.decode(Test.self, from: "a,d.1\n3,sdf")) // Complex as simple object
            try XCTAssertThrowsError(decoder.decode(Test.self, from: "a.0,d\n3,sdf")) // Complex as simple object
            try XCTAssertEqual(decoder.decode(Test.self, from: "a.0,d.1\n3,sdf"), [Test(a: [3], d: [1: "sdf"])])
        }
        do {
            try XCTAssertThrowsError(decoder.decode(Int.self, from: "\n1\n7,")) // Unequal rows
            try XCTAssertThrowsError(decoder.decode(Int.self, from: "b,a,a,d\n,,,")) // Duplicated field `a`
            try XCTAssertThrowsError(decoder.decode(Int.self, from: "b,,,d\n,,,")) // Duplicated field ``
            try XCTAssertThrowsError(decoder.decode(Int.self, from: "\"")) // Invalid CSV
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

    func testReadme() throws {
        struct SomeStruct: Equatable, Codable {
            var a: Int, b: Double?, c: String
        }
        struct OtherStruct: Equatable, Codable {
            var float: Float?, some: SomeStruct
        }

        do {
            let values = [
                OtherStruct(float: 5.5, some: .init(a: 4, b: .infinity, c: "abc")),
                OtherStruct(float: nil, some: .init(a: -3, b: nil, c: ""))
            ]

            let string = try encoder.encode(values)
            print(string)
        }
        do {
            let string = """
            a,b,c
            4,,test
            6,9.9,ss
            """

            let value = try decoder.decode(SomeStruct.self, from: string)
            XCTAssertEqual(value, [
                SomeStruct(a: 4, b: nil, c: "test"),
                SomeStruct(a: 6, b: 9.9, c: "ss")
                ])
        }
    }

    static var allTests = [
        ("testEscaping", testEscaping),
        ("testTokenizer", testTokenizer),
        ("testRoundtrip", testRoundtrip),

        ("testSingleValueRoundtrip", testSingleValueRoundtrip),
        ("testKeyedRoundtrip", testKeyedRoundtrip),
        ("testUnkeyedRoundtrip", testUnkeyedRoundtrip),

        ("testBehaviours", testBehaviours),

        ("testNestedKeyedContainers", testNestedKeyedContainers),
        ("testNestedUnkeyedContainer", testNestedUnkeyedContainer),

        ("testReadme", testReadme),
    ]
}

extension Tokens.Token: Equatable {
    public static func == (lhs: Tokens<S>.Token, rhs: Tokens<S>.Token) -> Bool {
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
