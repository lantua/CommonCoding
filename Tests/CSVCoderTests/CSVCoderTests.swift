import XCTest
@testable import CSVCoder

final class CSVCoderTests: XCTestCase {
    func testRoundtrip() throws {
        let encoder = CSVEncoder(), decoder = CSVDecoder()

        struct Test: Codable, Equatable {
            var a: Int, b: Double, c: Bool
        }

        do {
            let values = [Test(a: 1, b: 0.0, c: true), Test(a: -564, b: .ulpOfOne, c: false)]
            let string = try encoder.encode(values)
            let roundtrip = try decoder.decode(Test.self, string)
            XCTAssertEqual(roundtrip, values)
        }
        
        do {
            let values = [[Test(a: 1, b: 0.0, c: true), Test(a: 4, b: 5.9, c: true)], [Test(a: 3, b: -0.3, c: false), Test(a: 99, b: -.infinity, c: false)]]
            let string = try encoder.encode(values)
            let roundtrip = try decoder.decode([Test].self, string)
            XCTAssertEqual(values, roundtrip)
        }
        
        do {
            let values = [["d", "kkd", "ss"], ["as", "asd"]]
            let string = try encoder.encode(values)
            XCTAssertNoThrow(try decoder.decode([String].self, string))
        }
        
        do {
            let values = [1, 2, 3]
            let string = try encoder.encode(values)
            let roundtrip = try decoder.decode(Int.self, string)
            XCTAssertEqual(values, roundtrip)
        }

        do {
            struct Test: Codable, Hashable {
                var a: Int?, b: Double?, c: Float?, d: String?, e: Bool?
            }
            let values = [
                Test(a: nil, b: nil, c: nil, d: nil, e: true),
                Test(a: nil, b: 0.3, c: nil, d: "dsta", e: nil),
                Test(a: 2, b: 0.3, c: nil, d: "dsta", e: false),
            ]
            let string = try encoder.encode(values)
            let roundtrip = try decoder.decode(Test.self, string)
            XCTAssertEqual(values, roundtrip)
        }
    }
    
    func testEscaping() throws {
        struct Test: Codable, Equatable {
            var a: String
        }
        
        let string = """
        a
        "asd""jjdd
        f"

        "asd"
        """
        let expected = [Test(a: "asd\"jjdd\nf"), Test(a: "asd")]
        let result = try CSVDecoder().decode(Test.self, string)
        XCTAssertEqual(result, expected)
    }
    
    func testDecoding() throws {
        let decoder = CSVDecoder()

        do {
            struct Test: Decodable {
                var a: String
            }
            XCTAssertThrowsError(try decoder.decode(Test.self, "a\n\""))
            XCTAssertThrowsError(try decoder.decode(Test.self, "a\nasdf\"asdf"))
            XCTAssertThrowsError(try decoder.decode(Test.self, "a\n\"asdfasdf"))
            XCTAssertThrowsError(try decoder.decode(Test.self, "a\nasdfasdf\""))
            XCTAssertThrowsError(try decoder.decode(Test.self, "a\n\"asd\"fasdf\""))
            XCTAssertThrowsError(try decoder.decode(Test.self, "a,b,asdjh,\"asdf\",a\n\"asd\"fasdf\""))
        }
        
        do {
            struct Test: Decodable {
                var a: Bool, b: Int, c: Float, d: Double
            }
            XCTAssertThrowsError(try decoder.decode(Test.self, "a,b,c,d\ntrue,0,ffds,0.0"))
            XCTAssertThrowsError(try decoder.decode(Test.self, "a,b,c,d\ntrue,0,0.0,0.0."))
            XCTAssertThrowsError(try decoder.decode(Test.self, "a,b,c,d\nssjj,10,0,0.0"))
            XCTAssertThrowsError(try decoder.decode(Test.self, "a,b,c,d\ntrue,0.0,ffds,0.0"))
            XCTAssertNoThrow(try decoder.decode(Test.self, "a,b,c,d\ntrue,994,inf,0.0"))
        }
        
        XCTAssertThrowsError(try decoder.decode(Double.self, "a, kjskdj,a\n9949,9494,4"))
        
        XCTAssertEqual(try decoder.decode(String.self, "\nasjdkjfksadf"), ["asjdkjfksadf"])
        XCTAssertEqual(try decoder.decode(Int.self, "\n7737"), [7737])
        XCTAssertEqual(try decoder.decode(Double.self, "\n7737.0\n1.0"), [7737.0, 1.0])
        XCTAssertEqual(try decoder.decode(Float.self, "\n7737.0\n1.0"), [7737.0, 1.0])
        XCTAssertTrue(try decoder.decode(Double.self, "\nnan\nNan\nNan\nNaN").allSatisfy { $0.isNaN })
        
        XCTAssertThrowsError(try decoder.decode(Int.self, "\nasjdkjfksadf"))
        XCTAssertThrowsError(try decoder.decode(Double.self, "\nasjdkjfksadf"))
        XCTAssertThrowsError(try decoder.decode(Float.self, "\nasjdkjfksadf"))
        XCTAssertThrowsError(try decoder.decode(Bool.self, "\nasjdkjfksadf"))
    }
    
    func testNestedContainers() throws {
        class Base: Codable {
            var a: Int, b: String, c: Bool
            
            init(a: Int, b: String, c: Bool) {
                self.a = a
                self.b = b
                self.c = c
            }
        }
        class Derived: Base {
            var d: Float, e: Int
            
            init(a: Int, b: String, c: Bool, d: Float, e: Int) {
                self.d = d
                self.e = e
                
                super.init(a: a, b: b, c: c)
            }
            
            required init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                d = try container.decode(Float.self, forKey: .d)
                e = try container.decode(Int.self, forKey: .e)
                
                try super.init(from: container.superDecoder())
            }
            override func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(d, forKey: .d)
                try container.encode(e, forKey: .e)
                
                try super.encode(to: container.superEncoder())
            }
            
            enum CodingKeys: CodingKey {
                case d, e
            }
        }
        
        func matched(_ lhs: Derived, _ rhs: Derived) -> Bool {
            return lhs.a == rhs.a &&
                lhs.b == rhs.b &&
                lhs.c == rhs.c &&
                lhs.d == rhs.d &&
                lhs.e == rhs.e
        }

        let encoder = CSVEncoder(), decoder = CSVDecoder()
        
        let derived = [
            Derived(a: 2, b: "asd🧐jh", c: false, d: 0.4, e: 993),
            Derived(a: 10, b: "as\"dfjh", c: false, d: .infinity, e: -3),
        ]
        let string = try encoder.encode(derived)
        let roundtrip = try decoder.decode(Derived.self, string)
        
        XCTAssertEqual(derived.count, roundtrip.count)
        XCTAssert(zip(derived, roundtrip).allSatisfy { matched($0.0, $0.1) })
        
        do {
            struct Test: Codable, Equatable {
                struct Nested: Codable, Equatable {
                    struct Nested: Codable, Equatable {
                        var b: Double
                    }
                    var a: Int, b: Nested, c: [Int?]
                }
                var a: [Int], b: Nested
            }
            
            let values = [Test(a: [1, 2, 3], b: .init(a: 1, b: .init(b: 1), c: [nil, nil, 9])), Test(a: [10,9,8], b: .init(a: 99, b: .init(b: 0.004), c: [1, 2, 3]))]
            let string = try encoder.encode(values)
            let roundtrip = try decoder.decode(Test.self, string)
            XCTAssertEqual(values, roundtrip)
        }
    }

    static var allTests = [
        ("testRoundtrip", testRoundtrip),
        ("testEscaping", testEscaping),
        ("testDecodingFailure", testDecoding),
        ("testNestedContainers", testNestedContainers),
    ]
}
