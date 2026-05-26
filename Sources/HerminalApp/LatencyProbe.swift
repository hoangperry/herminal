// LatencyProbe — frame-tick latency instrumentation.
//
// Measures the CPU cost of each `ghostty_app_tick` (libghostty event
// processing + render preparation) and reports p50/p95/p99 periodically.
//
// NOTE ON SCOPE: this is a CPU-side proxy. It tells us whether herminal is
// CPU-bound per frame (p95 should sit well under the 8.3 ms budget at 120 Hz).
// True keydown→photon latency must be measured with an external tool
// (typometer / high-speed camera) — software cannot observe the photon.

import Foundation

@MainActor
final class LatencyProbe {
    static let shared = LatencyProbe()

    /// Sample count per report (~10 s at 60 Hz).
    private let reportEvery = 600
    private var samples: [Double] = []

    private init() {
        samples.reserveCapacity(reportEvery)
    }

    /// Records one `ghostty_app_tick` duration.
    func recordTick(_ duration: Duration) {
        samples.append(duration.milliseconds)
        if samples.count >= reportEvery { flush() }
    }

    /// Live p95 over whatever samples are currently buffered. Returns nil
    /// until we have at least 30 samples (~0.5 s of ticks) so the status
    /// bar doesn't display a misleading single-sample number.
    ///
    /// Cheap on purpose — copies + sorts the buffer, called once per
    /// second from the status bar. The full 600-sample window is only ~5
    /// KB of doubles, so the sort is well under 100 µs.
    func snapshotP95Milliseconds() -> Double? {
        guard samples.count >= 30 else { return nil }
        let sorted = samples.sorted()
        let index = min(Int(Double(sorted.count) * 0.95), sorted.count - 1)
        return sorted[index]
    }

    private func flush() {
        guard !samples.isEmpty else { return }
        let sorted = samples.sorted()
        NSLog(String(
            format: "herminal tick latency (n=%d): p50=%.3fms p95=%.3fms p99=%.3fms max=%.3fms",
            sorted.count,
            Self.percentile(sorted, fraction: 0.50),
            Self.percentile(sorted, fraction: 0.95),
            Self.percentile(sorted, fraction: 0.99),
            sorted.last ?? 0
        ))
        samples.removeAll(keepingCapacity: true)
    }

    /// Nearest-rank percentile: for `n` samples and fraction `f` the
    /// result is the `ceil(n*f)`-th sample (1-indexed) — i.e. the
    /// smallest sample that has at least `f` of the data at or below it.
    /// The earlier `Int(n*f)` truncation occasionally crossed the
    /// boundary by one element (n=100, f=0.95 → index 95 = the 96th
    /// element, slightly above strict p95). (M12 review LOW —
    /// code-reviewer finding 8.)
    private static func percentile(_ sorted: [Double], fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let rank = max(1, Int((Double(sorted.count) * fraction).rounded(.up)))
        return sorted[min(rank, sorted.count) - 1]
    }
}

private extension Duration {
    /// Duration as milliseconds (seconds + attoseconds → ms).
    var milliseconds: Double {
        let parts = components
        return Double(parts.seconds) * 1_000
            + Double(parts.attoseconds) / 1_000_000_000_000_000
    }
}
