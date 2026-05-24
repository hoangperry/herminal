import Foundation
import Testing
@testable import HerminalCore

/// BellRegistry is a singleton (its real-world counterpart is one
/// global because libghostty's action_cb is one global). Tests share
/// `BellRegistry.shared` and reset before each case — `.serialized`
/// ensures Swift Testing doesn't run them in parallel and let one
/// case's bells leak into another's counter assertion.
@Suite("BellRegistry", .serialized)
struct BellRegistryTests {
    /// Use a fresh BellRegistry isolation per test by resetting the
    /// singleton — `BellRegistry.shared` is one global because libghostty's
    /// action_cb is one global, so we can't inject. Reset gives test
    /// independence without re-architecting the singleton.
    private func freshRegistry() -> BellRegistry {
        let r = BellRegistry.shared
        r.reset()
        return r
    }

    @Test("recordBell increments the monotonic counter")
    func recordIncrements() {
        let registry = freshRegistry()
        #expect(registry.totalBells == 0)
        registry.recordBell(surfaceAddress: 0x1000)
        registry.recordBell(surfaceAddress: 0x1000)
        registry.recordBell(surfaceAddress: 0x2000)
        #expect(registry.totalBells == 3)
    }

    @Test("lastBell tracks the most recent ring per surface address")
    func lastBellPerSurface() {
        let registry = freshRegistry()
        let earlier = Date(timeIntervalSince1970: 1000)
        let later = Date(timeIntervalSince1970: 2000)
        registry.recordBell(surfaceAddress: 0x1000, at: earlier)
        registry.recordBell(surfaceAddress: 0x1000, at: later)
        #expect(registry.lastBell(forSurfaceAddress: 0x1000) == later)
        // Different surface — independent state.
        #expect(registry.lastBell(forSurfaceAddress: 0x2000) == nil)
    }

    @Test("hasRecentBell respects the time window")
    func hasRecentRespectsWindow() {
        let registry = freshRegistry()
        // Record a bell 30 seconds in the past.
        registry.recordBell(
            surfaceAddress: 0x1000,
            at: Date().addingTimeInterval(-30)
        )
        // 10s window: stale.
        #expect(!registry.hasRecentBell(forSurfaceAddress: 0x1000, within: 10))
        // 60s window: still fresh.
        #expect(registry.hasRecentBell(forSurfaceAddress: 0x1000, within: 60))
        // Surface that never rang: never has a recent bell.
        #expect(!registry.hasRecentBell(forSurfaceAddress: 0x9999, within: 60))
    }

    @Test("reset clears the counter and per-surface state")
    func resetClearsAll() {
        let registry = freshRegistry()
        registry.recordBell(surfaceAddress: 0x1000)
        registry.recordBell(surfaceAddress: 0x2000)
        registry.reset()
        #expect(registry.totalBells == 0)
        #expect(registry.lastBell(forSurfaceAddress: 0x1000) == nil)
        #expect(registry.lastBell(forSurfaceAddress: 0x2000) == nil)
    }
}
