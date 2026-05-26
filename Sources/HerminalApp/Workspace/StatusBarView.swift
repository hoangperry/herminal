// StatusBarView — the thin info strip at the window bottom.
//
// Four chips: tick-latency p95, agent count, diary file size, current
// theme. Refreshes once per second from a SwiftUI Timer publisher so we
// don't burn budget when the user has the status bar hidden — the host
// is removed from the view hierarchy in that case.
//
// Read-only: nothing here writes state. Clicks are not handled. If the
// owner wants a live tail of the diary they can open Console.app or
// run `tail -F ~/Library/Application Support/herminal/diary.log` —
// adding a click target here without a clear interaction would just be
// noise.

import SwiftUI

struct StatusBarView: View {
    /// Read these on every tick. They're computed properties on the
    /// caller's side so the view stays decoupled from the concrete
    /// LatencyProbe / AgentDetector / Diary types. Annotated `@MainActor`
    /// so the compiler enforces the main-thread call site — a future
    /// refactor that calls `probe` from a background `Task {}` won't
    /// silently trap inside `MainActor.assumeIsolated`. (M12 review HIGH
    /// — code-reviewer finding 1.)
    let probe: @MainActor () -> StatusSnapshot

    @State private var snapshot: StatusSnapshot = .empty

    /// 1 Hz refresh — the data sources are cheap (small array sort, one
    /// stat(2), one Int read) so we don't gain anything by going slower.
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    static let height: CGFloat = 22

    var body: some View {
        HStack(spacing: 16) {
            chip(label: "tick p95", value: snapshot.latencyText)
            chip(label: "agents", value: "\(snapshot.agentCount)")
            chip(label: "diary", value: snapshot.diarySizeText)
            chip(label: "theme", value: snapshot.themeText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HerminalDesign.Palette.surfaceElevated)
        .overlay(
            Rectangle()
                .fill(HerminalDesign.Palette.border)
                .frame(height: 1),
            alignment: .top
        )
        .onAppear { snapshot = probe() }
        .onReceive(timer) { _ in snapshot = probe() }
    }

    private func chip(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .default))
                .foregroundColor(HerminalDesign.Palette.textSecondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(HerminalDesign.Palette.textPrimary)
        }
    }
}

/// Snapshot of the live status. Sendable so SwiftUI can hand it across
/// the timer boundary cleanly.
struct StatusSnapshot: Sendable, Equatable {
    let agentCount: Int
    /// Tick p95 in milliseconds; nil means the probe hasn't gathered
    /// enough samples yet (warm-up window).
    let latencyP95: Double?
    let diaryBytes: Int64
    let themeText: String

    static let empty = StatusSnapshot(
        agentCount: 0,
        latencyP95: nil,
        diaryBytes: 0,
        themeText: "—"
    )

    var latencyText: String {
        guard let value = latencyP95 else { return "—" }
        return String(format: "%.1f ms", value)
    }

    var diarySizeText: String {
        if diaryBytes <= 0 { return "0 B" }
        if diaryBytes < 1_024 { return "\(diaryBytes) B" }
        if diaryBytes < 1_048_576 {
            return String(format: "%.1f KB", Double(diaryBytes) / 1_024)
        }
        return String(format: "%.2f MB", Double(diaryBytes) / 1_048_576)
    }
}
