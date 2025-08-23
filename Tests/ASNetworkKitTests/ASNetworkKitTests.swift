import XCTest
@testable import ASNetworkKit

final class ASNetworkKitTests: XCTestCase {
    func testURLConvertible() throws {
        XCTAssertNoThrow(try "https://example.com".asURL())
    }
}
