// ClaudeSessionsPanel — left-sidebar browser for resumable Claude Code
// sessions. Reads from ClaudeSessionStore (which scans ~/.claude/projects)
// and lets the user reopen any project: "Resume" runs `claude --resume`
// in the project's real cwd; "Shell" just drops a plain shell there.
//
// Mirrors SSHHostsPanel's shape (header + scrolling list + per-row hover)
// so the two sidebars feel like one family. Read-only — no edit/delete;
// the source of truth is Claude Code's own store.

import SwiftUI

struct ClaudeSessionsPanel: View {
    let sessions: [ClaudeProjectSession]
    /// Resume the project's newest conversation in its cwd.
    let onResume: (ClaudeProjectSession) -> Void
    /// Open a plain shell in the project's cwd (no claude).
    let onOpenShell: (ClaudeProjectSession) -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HerminalDesign.Palette.divider)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HerminalDesign.Palette.surfaceElevated)
    }

    private var header: some View {
        HStack(spacing: HerminalDesign.Spacing.xs) {
            Text("CLAUDE SESSIONS")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text("\(sessions.count)")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
            RefreshButton(action: onRefresh)
        }
        .padding(.horizontal, HerminalDesign.Spacing.md)
        .frame(height: TabBarView.barHeight)
    }

    @ViewBuilder
    private var content: some View {
        if sessions.isEmpty {
            VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xs) {
                Text("No Claude sessions found")
                    .font(HerminalDesign.Typography.body)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
                Text("Run `claude` in any project, then reopen this panel.")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HerminalDesign.Spacing.md)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xxs) {
                    ForEach(sessions) { session in
                        ClaudeSessionRow(
                            session: session,
                            onResume: { onResume(session) },
                            onOpenShell: { onOpenShell(session) }
                        )
                    }
                }
                .padding(HerminalDesign.Spacing.sm)
            }
        }
    }

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    static func relative(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct ClaudeSessionRow: View {
    let session: ClaudeProjectSession
    let onResume: () -> Void
    let onOpenShell: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(session.projectName)
                    .font(HerminalDesign.Typography.bodyEmphasis)
                    .foregroundStyle(HerminalDesign.Palette.textPrimary)
                    .lineLimit(1)
                Spacer()
                Button("Resume", action: onResume)
                    .font(HerminalDesign.Typography.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(HerminalDesign.Palette.accent)
                    .accessibilityLabel("Resume Claude in \(session.projectName)")
                    .accessibilityHint("Opens a tab running claude --resume in this project")
            }
            // cwd, truncated from the head so the tail (the meaningful
            // part) stays visible.
            Text(session.cwd)
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .lineLimit(1)
                .truncationMode(.head)
            HStack(spacing: HerminalDesign.Spacing.xs) {
                if let branch = session.gitBranch {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .labelStyle(.titleAndIcon)
                        .font(HerminalDesign.Typography.caption)
                        .foregroundStyle(HerminalDesign.Palette.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Text(ClaudeSessionsPanel.relative(session.lastActive))
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textTertiary)
            }
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .padding(.vertical, HerminalDesign.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .fill(isHovered
                      ? HerminalDesign.Palette.surfaceOverlay.opacity(1.3)
                      : HerminalDesign.Palette.surfaceOverlay)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .strokeBorder(
                    isHovered ? HerminalDesign.Palette.accent.opacity(0.35) : Color.clear,
                    lineWidth: 1
                )
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: HerminalDesign.Motion.fast), value: isHovered)
        .contextMenu {
            Button("Resume Claude", action: onResume)
            Button("Open Shell Here", action: onOpenShell)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Claude session \(session.projectName), last active \(ClaudeSessionsPanel.relative(session.lastActive))")
    }
}

private struct RefreshButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isHovered
                                 ? HerminalDesign.Palette.accent
                                 : HerminalDesign.Palette.textSecondary)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovered ? HerminalDesign.Palette.surfaceOverlay : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: HerminalDesign.Motion.fast), value: isHovered)
        .accessibilityLabel("Refresh Claude session list")
    }
}
