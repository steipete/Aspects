import XCTest
@testable import Aspects

final class AspectsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Aspects().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
