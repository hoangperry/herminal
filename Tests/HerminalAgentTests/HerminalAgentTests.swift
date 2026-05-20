import XCTest
@testable import HerminalAgent

final class HerminalAgentTests: XCTestCase {
    func testAgentKindRawValues() {
        XCTAssertEqual(AgentKind.claudeCode.rawValue, "claude")
        XCTAssertEqual(AgentKind.codex.rawValue, "codex")
    }

    func testAgentStatusUnknownAsDefault() {
        XCTAssertEqual(AgentStatus.unknown.rawValue, "unknown")
    }
}
