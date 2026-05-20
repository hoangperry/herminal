import XCTest
@testable import HerminalCore

final class HerminalCoreTests: XCTestCase {
    func testVersionFormat() {
        XCTAssertFalse(HerminalCore.version.isEmpty)
        XCTAssertTrue(HerminalCore.version.contains("."))
    }
}
