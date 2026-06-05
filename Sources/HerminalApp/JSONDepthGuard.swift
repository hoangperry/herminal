// JSONDepthGuard — a cheap, iterative nesting-depth check run BEFORE any
// recursive Codable decode of on-disk JSON.
//
// Why: `LayoutSnapshot` (the persisted split tree) is an `indirect enum`,
// so JSONDecoder instantiates it recursively. A crafted or corrupt
// workspace.json / workspaces.json with thousands of nested `.split`
// nodes would blow the call stack *inside the decoder* — before sanitise
// ever runs — crashing herminal on launch in an unrecoverable boot loop
// (the file reloads, re-crashes). A real layout nests <10 levels; this
// rejects anything absurd. (v0.5 security review — CRITICAL finding.)
//
// The scan is a single linear pass over the raw bytes counting structural
// `{ [ } ]` depth (skipping anything inside string literals), so it is
// itself O(n) and non-recursive — it cannot overflow on the very input it
// guards against.

import Foundation

enum JSONDepthGuard {
    /// A real workspace tree is a handful of levels deep; each split adds
    /// ~3-4 JSON nesting levels. 200 brackets ≈ 50 split levels — far past
    /// anything reachable through the UI, yet trivially rejects a
    /// thousands-deep malicious file.
    static let maxDepth = 200

    private static let quote: UInt8 = 0x22       // "
    private static let backslash: UInt8 = 0x5C   // \
    private static let openBrace: UInt8 = 0x7B    // {
    private static let openBracket: UInt8 = 0x5B  // [
    private static let closeBrace: UInt8 = 0x7D   // }
    private static let closeBracket: UInt8 = 0x5D // ]

    /// Returns true if `data` nests structurally deeper than `max` — the
    /// caller should refuse to decode it.
    static func exceedsMaxDepth(_ data: Data, max: Int = maxDepth) -> Bool {
        var depth = 0
        var inString = false
        var escaped = false
        for byte in data {
            if inString {
                if escaped {
                    escaped = false
                } else if byte == backslash {
                    escaped = true
                } else if byte == quote {
                    inString = false
                }
                continue
            }
            switch byte {
            case quote:
                inString = true
            case openBrace, openBracket:
                depth += 1
                if depth > max { return true }
            case closeBrace, closeBracket:
                depth -= 1
            default:
                break
            }
        }
        return false
    }
}
