import XCTest

import CSVCoderTests

var tests = [XCTestCaseEntry]()
tests += SharedTests.allTests()
tests += CSVCoderTests.allTests()
tests += BinaryCoderTests.allTests()
XCTMain(tests)
