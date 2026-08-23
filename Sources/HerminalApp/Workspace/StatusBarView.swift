// StatusBarView — the thin info strip at the window bottom.
//
// Live cwd actions plus four chips: tick-latency p95, agent count, diary
// file size, current theme. Refreshes once per second from a SwiftUI Timer publisher so we
// don't burn budget when the user has the status bar hidden — the host
// is removed from the view hierarchy in that case.

import AppKit
import SwiftUI

@MainActor
enum StatusBarWorkingDirectoryActions {
    struct Availability: Equatable {
        let canCopy: Bool
        let canReveal: Bool
    }

    enum Outcome: Equatable {
        case copied
        case revealed
        case unavailable
        case failed
    }

    struct Feedback: Equatable {
        let label: String
        let announcement: String
        let shouldBeep: Bool
    }

    static func availability(for path: String?) -> Availability {
        let isAvailable = usablePath(path) != nil
        return Availability(canCopy: isAvailable, canReveal: isAvailable)
    }

    /// Copies the unabridged cwd reported by the terminal. The shared
    /// pasteboard transaction restores every prior item when a write fails.
    static func copy(
        _ path: String?,
        to pasteboard: NSPasteboard = .general,
        commit: (String, NSPasteboard) -> Bool = { payload, pasteboard in
            pasteboard.setString(payload, forType: .string)
        }
    ) -> Outcome {
        guard let path = usablePath(path) else { return .unavailable }
        switch DiagnosticDiaryClipboard.write(path, to: pasteboard, commit: commit) {
        case .copied:
            return .copied
        case .empty:
            return .unavailable
        case .failed:
            return .failed
        }
    }

    /// Reveals only a path that still resolves to a directory. The terminal
    /// may retain its last OSC 7 value after a directory is moved or removed,
    /// so validation happens at activation time rather than at render time.
    static func reveal(
        _ path: String?,
        directoryExists: (URL) -> Bool = { url in
            var isDirectory = ObjCBool(false)
            let exists = FileManager.default.fileExists(
                atPath: url.path,
                isDirectory: &isDirectory
            )
            return exists && isDirectory.boolValue
        },
        revealInFinder: (URL) -> Bool = { url in
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return true
        }
    ) -> Outcome {
        guard let path = usablePath(path) else { return .unavailable }
        let url = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        guard directoryExists(url), revealInFinder(url) else { return .failed }
        return .revealed
    }

    static func feedback(for outcome: Outcome) -> Feedback {
        switch outcome {
        case .copied:
            return Feedback(
                label: "Copied",
                announcement: "Working directory copied.",
                shouldBeep: false
            )
        case .revealed:
            return Feedback(
                label: "Revealed",
                announcement: "Working directory revealed in Finder.",
                shouldBeep: false
            )
        case .unavailable:
            return Feedback(
                label: "Unavailable",
                announcement: "No working directory is available yet.",
                shouldBeep: true
            )
        case .failed:
            return Feedback(
                label: "Failed",
                announcement: "Working directory action failed.",
                shouldBeep: true
            )
        }
    }

    private static func usablePath(_ path: String?) -> String? {
        WorkingDirectoryPath.validated(path)
    }
}

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
    @State private var directoryFeedback: StatusBarWorkingDirectoryActions.Feedback?
    @State private var directoryFeedbackRevision = 0
    @State private var isDirectoryHovered = false
    @FocusState private var isDirectoryFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 1 Hz refresh — the data sources are cheap (small array sort, one
    /// stat(2), one Int read) so we don't gain anything by going slower.
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    static let height = HerminalDesign.Geometry.compactInteractiveControlSize

    var body: some View {
        HStack(spacing: 16) {
            // cwd is the headline — it sits on the left and truncates from
            // the middle so the path's head + tail stay legible. The
            // diagnostic chips are pushed to the right by the Spacer.
            cwdChip
            Spacer(minLength: 12)
            HStack(spacing: 16) {
                chip(label: "tick p95", value: snapshot.latencyText)
                chip(label: "agents", value: "\(snapshot.agentCount)")
                chip(label: "diary", value: snapshot.diarySizeText)
                chip(label: "theme", value: snapshot.themeText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Workspace diagnostics")
            .accessibilityValue(snapshot.diagnosticsAccessibilityValue)
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
        // Keep the working-directory menu and read-only diagnostics as two
        // concise VoiceOver stops. The former is actionable; flattening the
        // whole strip would hide those actions from assistive technology.
        .accessibilityElement(children: .contain)
        .onAppear { snapshot = probe() }
        .onReceive(timer) { _ in snapshot = probe() }
        .task(id: directoryFeedbackRevision) {
            guard directoryFeedback != nil else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: HerminalDesign.Motion.fast)) {
                directoryFeedback = nil
            }
        }
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

    /// The focused pane's working directory — a folder glyph + the path,
    /// truncated from the middle when the window is narrow so both the
    /// repo root and the leaf dir stay readable.
    private var cwdChip: some View {
        Menu {
            Button("Copy Full Path", systemImage: "doc.on.doc") {
                recordDirectoryOutcome(
                    StatusBarWorkingDirectoryActions.copy(snapshot.cwd)
                )
            }
            Button("Reveal in Finder", systemImage: "folder") {
                recordDirectoryOutcome(
                    StatusBarWorkingDirectoryActions.reveal(snapshot.cwd)
                )
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: directoryFeedbackSymbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(directoryFeedbackColor)
                    .accessibilityHidden(true)
                Text(directoryFeedback?.label ?? snapshot.cwdText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(directoryFeedbackColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if directoryFeedback == nil, let branch = snapshot.gitBranch {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(HerminalDesign.Palette.accent)
                        .padding(.leading, 2)
                        .accessibilityHidden(true)
                    Text(branch)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(HerminalDesign.Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(HerminalDesign.Palette.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, HerminalDesign.Spacing.xs)
            .frame(minHeight: Self.height)
            .background(
                Rectangle().fill(
                    isDirectoryHovered || isDirectoryFocused
                        ? HerminalDesign.Palette.surfaceOverlay
                        : Color.clear
                )
            )
            .overlay(
                Rectangle().strokeBorder(
                    isDirectoryFocused
                        ? HerminalDesign.Palette.accent.opacity(0.62)
                        : Color.clear,
                    lineWidth: 1
                )
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .disabled(!StatusBarWorkingDirectoryActions.availability(for: snapshot.cwd).canCopy)
        .focused($isDirectoryFocused)
        .onHover { isDirectoryHovered = $0 }
        .accessibilityLabel("Working directory actions")
        .accessibilityValue(snapshot.workingDirectoryAccessibilityValue)
        .accessibilityHint("Opens actions to copy the full path or reveal it in Finder")
        .help("Working directory actions")
        .layoutPriority(1)
    }

    private var directoryFeedbackSymbol: String {
        guard let directoryFeedback else { return "folder" }
        return directoryFeedback.shouldBeep ? "exclamationmark.triangle.fill" : "checkmark"
    }

    private var directoryFeedbackColor: Color {
        guard let directoryFeedback else { return HerminalDesign.Palette.textPrimary }
        return directoryFeedback.shouldBeep
            ? HerminalDesign.Palette.statusError
            : HerminalDesign.Palette.accent
    }

    private func recordDirectoryOutcome(
        _ outcome: StatusBarWorkingDirectoryActions.Outcome
    ) {
        let feedback = StatusBarWorkingDirectoryActions.feedback(for: outcome)
        if feedback.shouldBeep { NSSound.beep() }
        withAnimation(reduceMotion ? nil : .easeOut(duration: HerminalDesign.Motion.fast)) {
            directoryFeedback = feedback
            directoryFeedbackRevision += 1
        }
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: feedback.announcement,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
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
    /// Focused pane's full working directory. nil when no pane has reported
    /// one (OSC 7) yet. Presentation abbreviates the home prefix only.
    let cwd: String?
    /// Focused pane's git branch, nil outside a repo.
    let gitBranch: String?

    static let empty = StatusSnapshot(
        agentCount: 0,
        latencyP95: nil,
        diaryBytes: 0,
        themeText: "—",
        cwd: nil,
        gitBranch: nil
    )

    var cwdText: String { cwd.map { PathLabel.abbreviateHome($0) } ?? "—" }

    var latencyText: String {
        guard let value = latencyP95 else { return "—" }
        // A healthy tick is tens of microseconds, and "%.1f ms" flattened
        // every one of them to a broken-looking "0.0 ms". Switch units
        // below a millisecond so the chip reports the real number — which
        // happens to be the figure worth showing off.
        if value < 1 { return String(format: "%.0f µs", value * 1_000) }
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

    /// Natural-language mirror of the visual strip. Visual abbreviations
    /// such as µs, KB, and the em-dash warm-up placeholder are expanded so
    /// VoiceOver does not have to guess how to pronounce them.
    var accessibilityValue: String {
        [workingDirectoryAccessibilityValue, diagnosticsAccessibilityValue]
            .joined(separator: ", ")
    }

    var workingDirectoryAccessibilityValue: String {
        var parts = [
            cwd.map { "Working directory \(PathLabel.abbreviateHome($0))" }
                ?? "Working directory unavailable"
        ]
        if let gitBranch, !gitBranch.isEmpty { parts.append("Git branch \(gitBranch)") }
        return parts.joined(separator: ", ")
    }

    var diagnosticsAccessibilityValue: String {
        [
            "tick p95 \(accessibilityLatencyText)",
            "\(agentCount) \(agentCount == 1 ? "agent" : "agents")",
            "diary \(accessibilityDiarySizeText)",
            "theme \(themeText == "—" || themeText.isEmpty ? "unavailable" : themeText)"
        ].joined(separator: ", ")
    }

    private var accessibilityLatencyText: String {
        guard let value = latencyP95 else { return "warming up" }
        if value < 1 {
            return String(format: "%.0f microseconds", value * 1_000)
        }
        return String(format: "%.1f milliseconds", value)
    }

    private var accessibilityDiarySizeText: String {
        if diaryBytes <= 0 { return "empty" }
        if diaryBytes == 1 { return "1 byte" }
        if diaryBytes < 1_024 { return "\(diaryBytes) bytes" }
        if diaryBytes < 1_048_576 {
            return String(format: "%.1f kilobytes", Double(diaryBytes) / 1_024)
        }
        return String(format: "%.2f megabytes", Double(diaryBytes) / 1_048_576)
    }
}
