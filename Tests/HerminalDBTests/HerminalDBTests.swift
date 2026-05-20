import XCTest
@testable import HerminalDB

final class HerminalDBTests: XCTestCase {
    func testSchemaVersionPositive() {
        XCTAssertGreaterThan(HerminalDB.schemaVersion, 0)
    }
}
