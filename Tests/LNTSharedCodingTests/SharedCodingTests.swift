import XCTest
@testable import LNTSharedCoding

final class SharedCodingTests: XCTestCase {
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

    static var allTests = [
        ("testCodingKeys", testCodingKeys),
    ]
}
