import XCTest

import LNTCSVCoderTests
import LNTBinaryCoderTests

var tests = [XCTestCaseEntry]()
tests += LNTCSVCoderTests.allTests()
tests += LNTBinaryCoderTests.allTests()
XCTMain(tests)
