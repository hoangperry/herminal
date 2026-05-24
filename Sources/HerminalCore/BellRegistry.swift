// BellRegistry — records when libghostty fires GHOSTTY_ACTION_RING_BELL on a
// surface. The bell is the canonical "I need your attention" signal a TUI can
// emit; Claude Code / Codex / many agent CLIs ring it when they're waiting on
// the user. The agent dashboard reads this registry to flip an agent from
// `.idle` to `.needsInput` (Q6-001).
//
// Threading: libghostty fires action_cb from arbitrary threads (renderer,
// IO, runtime). Reads come from the @MainActor agent-poll cycle. Lock with
// a tiny NSLock — bell events are infrequent, contention is negligible.

import Foundation

/// Singleton tracking the most recent BEL ring per surface (keyed on
/// libghostty's opaque surface pointer, treated here as an `Int` address)
/// plus a global monotonic counter for tests.
public final class BellRegistry: @unchecked Sendable {
    public static let shared = BellRegistry()

    /// Total bells observed across every surface since process start.
    /// Strictly monotonic — used by tests to verify the action_cb path
    /// fires without needing a real PTY shell to emit BEL.
    public var totalBells: Int {
        lock.lock()
        defer { lock.unlock() }
        return _totalBells
    }

    private let lock = NSLock()
    private var _totalBells = 0
    /// Surface address → last ring date. `Int` (the address as an integer)
    /// because the raw pointer isn't `Hashable` and storing it as `Any`
    /// would require an unsafe cast on every lookup.
    private var lastByAddress: [Int: Date] = [:]

    private init() {}

    /// Records a bell event. Safe to call from any thread.
    public func recordBell(surfaceAddress: Int, at instant: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        _totalBells += 1
        lastByAddress[surfaceAddress] = instant
    }

    /// Returns the date of the most recent bell on `surfaceAddress`, or
    /// nil if no bell has ever rung on that surface.
    public func lastBell(forSurfaceAddress address: Int) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return lastByAddress[address]
    }

    /// True when `surfaceAddress` rang its bell within the trailing
    /// `window` seconds. The agent-status code reads this with
    /// `window = 10` so the `needs input` badge sticks long enough for a
    /// human to look up at the dashboard.
    public func hasRecentBell(
        forSurfaceAddress address: Int,
        within window: TimeInterval = 10
    ) -> Bool {
        guard let last = lastBell(forSurfaceAddress: address) else { return false }
        return Date().timeIntervalSince(last) <= window
    }

    /// Drop everything — used by tests to keep cases independent and by
    /// callers that want to reset state when the user clears a notification.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        _totalBells = 0
        lastByAddress.removeAll()
    }
}
