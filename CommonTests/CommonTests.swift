import XCTest
@testable import Common

final class CommonTests: XCTestCase {
    func testSchema() throws {
        let schema: Schema<Int> = .unkeyed([
            .single(1),
            .unkeyed([.noData]),
            .keyed(["test": .single(9)
                ])
            ])
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
            "unkeyed": [ 4, { "single": 4 } ],
            "single": 3,
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        try XCTAssertThrowsError(decoder.decode(Schema<Int>.self, from: data))
    }

    static var allTests = [
        ("testSchema", testSchema),
        ("testSchemaErrors", testSchemaErrors),
    ]
}

extension Schema: Equatable where Value: Equatable {
    public static func ==(lhs: Schema, rhs: Schema) -> Bool {
        switch (lhs, rhs) {
        case let (.single(x), .single(y)): return x == y
        case let (.unkeyed(x), .unkeyed(y)): return x == y
        case let (.keyed(x), .keyed(y)): return x == y
        case (.noData, .noData): return true
        default: return false
        }
    }
}
