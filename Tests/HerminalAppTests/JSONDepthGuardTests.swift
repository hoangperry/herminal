import Foundation
import Testing
@testable import HerminalApp

// Pins the v0.5 CRITICAL fix: reject pathologically deep JSON before a
// recursive Codable decode can overflow the stack on launch.
@Suite("JSONDepthGuard")
struct JSONDepthGuardTests {
    private func data(_ s: String) -> Data { Data(s.utf8) }

    @Test("a shallow object is accepted")
    func shallowOK() {
        #expect(!JSONDepthGuard.exceedsMaxDepth(data(#"{"a": 1, "b": [1, 2, 3]}"#)))
    }

    @Test("a realistic nested layout is accepted")
    func realisticOK() {
        // ~6 split levels — deeper than any real workspace, well under cap.
        let nested = String(repeating: #"{"split":{"first":"#, count: 6)
            + #"{"leaf":0}"# + String(repeating: "}}", count: 6)
        #expect(!JSONDepthGuard.exceedsMaxDepth(data(nested)))
    }

    @Test("nesting past the cap is rejected")
    func deepRejected() {
        let deep = String(repeating: "[", count: 5000) + String(repeating: "]", count: 5000)
        #expect(JSONDepthGuard.exceedsMaxDepth(data(deep)))
    }

    @Test("braces inside string literals are not counted")
    func bracesInStringsIgnored() {
        // 300 '{' but all inside a single string value → depth stays 2.
        let payload = "{\"x\": \"" + String(repeating: "{", count: 300) + "\"}"
        #expect(!JSONDepthGuard.exceedsMaxDepth(data(payload)))
    }

    @Test("an escaped quote does not prematurely end the string scan")
    func escapedQuoteHandled() {
        // The \" keeps us inside the string, so the trailing { stays counted
        // as string content, not structure.
        let payload = #"{"x": "a\"b{{{{{"}"#
        #expect(!JSONDepthGuard.exceedsMaxDepth(data(payload)))
    }

    @Test("the cap parameter is honoured")
    func customCap() {
        let six = String(repeating: "[", count: 6) + String(repeating: "]", count: 6)
        #expect(JSONDepthGuard.exceedsMaxDepth(data(six), max: 5))
        #expect(!JSONDepthGuard.exceedsMaxDepth(data(six), max: 6))
    }
}
