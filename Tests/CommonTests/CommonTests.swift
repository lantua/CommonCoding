import XCTest
@testable import Common

final class CommonTests: XCTestCase {
    func testSchema() throws {
        let schema: Schema<Int> = [
            .init(value: 1),
            [.init()],
            ["test": .init(value: 9)]
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        try XCTAssertEqual(decoder.decode(Schema<Int>.self, from: encoder.encode(schema)), schema)

        XCTAssertTrue(schema.contains { $0 == 1 })
        XCTAssertTrue(schema.contains { $0 == 9 })
        XCTAssertFalse(schema.contains { $0 == 2 })
    }
    func testSchemaErrors() throws {
        let data = """
        {
            "unkeyed": [ 4, { "value": 4 } ],
            "value": 3,
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        try XCTAssertThrowsError(decoder.decode(Schema<Int>.self, from: data))
    }
    func testSchemaConversion() throws {
        struct IntKey: CodingKey {
            var index: Int

            var stringValue: String { return String(index) }
            var intValue: Int? { return index }

            init?(stringValue: String) {
                guard let result = Int(stringValue) else {
                    return nil
                }
                index = result
            }

            init?(intValue: Int) {
                index = intValue
            }
        }
        let a = Schema(value: 1), b = Schema<Int>(), c = Schema(value: 34)
        do {
            let schema: Schema<Int> = [a, b, c]
            XCTAssertEqual(schema.getContainer(keyedBy: IntKey.self), ["0": a, "1": b, "2": c])
            XCTAssertEqual(schema.getUnkeyedContainer(), [a, b, c])
            XCTAssertEqual(schema.getContainer(keyedBy: IntKey.self), ["0": a, "1": b, "2": c])
            XCTAssertEqual(schema.getUnkeyedContainer(), [a, b, c])
            XCTAssertNil(schema.getValue())

            schema.clearCache()

            XCTAssertEqual(schema.getContainer(keyedBy: IntKey.self), ["0": a, "1": b, "2": c])
            XCTAssertEqual(schema.getUnkeyedContainer(), [a, b, c])
            XCTAssertEqual(schema.getContainer(keyedBy: IntKey.self), ["0": a, "1": b, "2": c])
            XCTAssertEqual(schema.getUnkeyedContainer(), [a, b, c])
            XCTAssertNil(schema.getValue())
        }
        do {
            let schema: Schema = ["a": a, "2": b, "c": c]
            XCTAssertEqual(schema.getContainer(keyedBy: IntKey.self), ["2": b])
            XCTAssertEqual(schema.getUnkeyedContainer(), [.init(), .init(), b])
            XCTAssertNil(schema.getValue())

            schema.clearCache()

            XCTAssertEqual(schema.getContainer(keyedBy: IntKey.self), ["2": b])
            XCTAssertEqual(schema.getUnkeyedContainer(), [.init(), .init(), b])
            XCTAssertNil(schema.getValue())
        }
        do {
            let schema: Schema = ["a": a, "x": b, "c": c]
            XCTAssertEqual(schema.getContainer(keyedBy: IntKey.self), [:])
            XCTAssertEqual(schema.getUnkeyedContainer(), [])
            XCTAssertNil(schema.getValue())

            schema.clearCache()

            XCTAssertEqual(schema.getContainer(keyedBy: IntKey.self), [:])
            XCTAssertEqual(schema.getUnkeyedContainer(), [])
            XCTAssertNil(schema.getValue())
        }
        do {
            XCTAssertEqual(a.getValue(), 1)
            XCTAssertNil(b.getValue())
            XCTAssertEqual(c.getValue(), 34)

            XCTAssertNil(a.getUnkeyedContainer())
            XCTAssertNil(b.getUnkeyedContainer())
            XCTAssertNil(c.getUnkeyedContainer())

            XCTAssertNil(a.getContainer(keyedBy: IntKey.self))
            XCTAssertNil(b.getContainer(keyedBy: IntKey.self))
            XCTAssertNil(c.getContainer(keyedBy: IntKey.self))
        }
    }

    static var allTests = [
        ("testSchema", testSchema),
        ("testSchemaErrors", testSchemaErrors),
    ]
}

extension Schema: Equatable where Value: Equatable {
    public static func ==(lhs: Schema, rhs: Schema) -> Bool {
        switch (lhs.data, rhs.data) {
        case let (.value(x), .value(y)): return x == y
        case let (.unkeyed(x), .unkeyed(y)): return x == y
        case let (.keyed(x), .keyed(y)): return x == y
        case (.empty, .empty): return true
        default: return false
        }
    }
}
