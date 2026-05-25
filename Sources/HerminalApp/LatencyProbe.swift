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
        func percentile(_ fraction: Double) -> Double {
            let index = min(Int(Double(sorted.count) * fraction), sorted.count - 1)
            return sorted[index]
        }
        NSLog(String(
            format: "herminal tick latency (n=%d): p50=%.3fms p95=%.3fms p99=%.3fms max=%.3fms",
            sorted.count,
            percentile(0.50), percentile(0.95), percentile(0.99),
            sorted.last ?? 0
        ))
        samples.removeAll(keepingCapacity: true)
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
