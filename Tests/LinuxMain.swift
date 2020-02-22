import XCTest

import LNTCSVCodingTests
import LNTBinaryCodingTests
import LNTSharedCodingTests

var tests = [XCTestCaseEntry]()
tests += LNTSharedCodingTests.allTests()
tests += LNTCSVCodingTests.allTests()
tests += LNTBinaryCodingTests.allTests()
XCTMain(tests)
