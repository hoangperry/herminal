// HerminalCore — libghostty C ABI bindings and Swift wrapper.
// Owns: terminal session lifecycle, PTY plumbing via libghostty, event bridge to AppKit.
// Does NOT own: SwiftUI views, SQLite, agent heuristics.

import Foundation

public enum HerminalCore {
    public static let version = "0.0.1-pre-alpha"
}
