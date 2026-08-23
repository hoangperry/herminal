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

    // 4.28, not 4.25: a value exactly on the .x5 boundary is representable
    // in binary and %.1f rounds it half-to-even, so 4.25 formats as "4.2".
    @Test("Milliseconds keep one decimal")
    func millisecondsKeepOneDecimal() {
        #expect(snapshot(latencyP95: 4.28).latencyText == "4.3 ms")
        #expect(snapshot(latencyP95: 12.0).latencyText == "12.0 ms")
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

    @Test("A stored full home path is abbreviated only for presentation")
    func cwdPresentationAbbreviatesStoredFullPath() {
        let fullPath = NSHomeDirectory() + "/pet-project/herminal"
        let snapshot = StatusSnapshot(
            agentCount: 0,
            latencyP95: nil,
            diaryBytes: 0,
            themeText: "dark",
            cwd: fullPath,
            gitBranch: nil
        )

        #expect(snapshot.cwd == fullPath)
        #expect(snapshot.cwdText == "~/pet-project/herminal")
        #expect(
            snapshot.workingDirectoryAccessibilityValue
                == "Working directory ~/pet-project/herminal"
        )
    }

    @Test("Accessibility summary speaks every visible status once")
    func accessibilitySummaryIncludesEveryStatus() {
        let fullPath = NSHomeDirectory() + "/pet-project/herminal"
        let value = StatusSnapshot(
            agentCount: 1,
            latencyP95: 0.042,
            diaryBytes: 2_048,
            themeText: "dark",
            cwd: fullPath,
            gitBranch: "main"
        ).accessibilityValue

        #expect(
            value == "Working directory ~/pet-project/herminal, Git branch main, "
                + "tick p95 42 microseconds, 1 agent, diary 2.0 kilobytes, theme dark"
        )
    }

    @Test("Accessibility summary replaces visual placeholders with spoken states")
    func accessibilitySummarySpeaksUnavailableStates() {
        #expect(
            StatusSnapshot.empty.accessibilityValue
                == "Working directory unavailable, tick p95 warming up, "
                + "0 agents, diary empty, theme unavailable"
        )
    }
}
