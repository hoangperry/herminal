import Foundation
import Testing
@testable import HerminalApp

// StatusSnapshot formats the status-bar chips. Pure value type, so these
// assert the display rules directly without standing up a window.
@Suite("StatusSnapshot")
struct StatusSnapshotTests {

    private func snapshot(latencyP95: Double?) -> StatusSnapshot {
        StatusSnapshot(
            agentCount: 0,
            latencyP95: latencyP95,
            diaryBytes: 0,
            themeText: "dark",
            cwd: nil,
            gitBranch: nil
        )
    }

    @Test("A sub-millisecond tick reports microseconds, not 0.0 ms")
    func subMillisecondUsesMicroseconds() {
        #expect(snapshot(latencyP95: 0.042).latencyText == "42 µs")
    }

    @Test("Milliseconds keep one decimal")
    func millisecondsKeepOneDecimal() {
        #expect(snapshot(latencyP95: 4.25).latencyText == "4.3 ms")
    }

    @Test("The unit switches at exactly 1 ms")
    func unitBoundaryIsOneMillisecond() {
        #expect(snapshot(latencyP95: 0.999).latencyText == "999 µs")
        #expect(snapshot(latencyP95: 1.0).latencyText == "1.0 ms")
    }

    @Test("A warm-up window with no samples shows an em dash")
    func noSamplesShowsDash() {
        #expect(snapshot(latencyP95: nil).latencyText == "—")
    }

    @Test("Diary size steps through B, KB and MB")
    func diarySizeUnits() {
        func text(_ bytes: Int64) -> String {
            StatusSnapshot(
                agentCount: 0, latencyP95: nil, diaryBytes: bytes,
                themeText: "dark", cwd: nil, gitBranch: nil
            ).diarySizeText
        }
        #expect(text(0) == "0 B")
        #expect(text(512) == "512 B")
        #expect(text(2_048) == "2.0 KB")
        #expect(text(5_242_880) == "5.00 MB")
    }
}
