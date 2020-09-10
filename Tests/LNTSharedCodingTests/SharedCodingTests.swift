import XCTest
@testable import LNTSharedCoding

final class SharedCodingTests: XCTestCase {
    func testUnkeyedCodingKey() {
        let key1: CodingKey = UnkeyedCodingKey(intValue: 9988)
        XCTAssertEqual(key1.intValue, 9988)
        XCTAssertEqual(key1.stringValue, "9988")

        let key2: CodingKey? = UnkeyedCodingKey(stringValue: "someValue")
        XCTAssertNil(key2)

        let key3: CodingKey? = UnkeyedCodingKey(stringValue: "1234")
        XCTAssertEqual(key3?.intValue, 1234)
        XCTAssertEqual(key3?.stringValue, "1234")
    }

    func testSuperCodingKey() {
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

    func testCodingPath() {
        var codingPath = CodingPath.root
        do {
            let codingPath = codingPath.expanded
            XCTAssert(codingPath.isEmpty)
        }
        codingPath = .child(key: UnkeyedCodingKey(intValue: 3), parent: codingPath)
        do {
            let codingPath = codingPath.expanded
            XCTAssert(codingPath.count == 1)
            XCTAssert(codingPath[0] is UnkeyedCodingKey)
            XCTAssert(codingPath[0].intValue == 3)
        }
        codingPath = .child(key: SuperCodingKey(), parent: codingPath)
        do {
            let codingPath = codingPath.expanded
            XCTAssert(codingPath.count == 2)
            XCTAssert(codingPath[0] is UnkeyedCodingKey)
            XCTAssert(codingPath[0].intValue == 3)
            XCTAssert(codingPath[1] is SuperCodingKey)
        }
    }

    static var allTests = [
        ("testUnkeyedCodingKey", testUnkeyedCodingKey),
        ("testSuperCodingKey", testSuperCodingKey),
        ("testCodingPath", testCodingPath),
    ]
}
