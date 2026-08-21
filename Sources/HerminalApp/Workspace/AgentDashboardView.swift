// AgentDashboardView — sidebar panel listing the agent CLIs running under
// herminal, plus the worktree cockpit (new agent pane, isolated
// worktrees, lazygit) and live tmux sessions (attach / named new /
// confirm-kill).
//
// Lifecycle status is inferred outside the view from CPU deltas and recent
// terminal bells. This view only renders privacy-minimized DetectedAgent values.

import SwiftUI
import HerminalAgent

struct AgentDashboardView: View {
    let agents: [DetectedAgent]
    var worktrees: [GitWorktree.Entry] = []
    var inGitRepo: Bool = false
    var primaryWorktreePath: String? = nil
    var onSelectAgent: ((DetectedAgent) -> Void)?
    var onNewAgent: (() -> Void)?
    var onNewWorktree: (() -> Void)?
    var onOpenLazygit: (() -> Void)?
    var onOpenWorktree: ((GitWorktree.Entry) -> Void)?
    var onAgentInWorktree: ((GitWorktree.Entry) -> Void)?
    var onRemoveWorktree: ((GitWorktree.Entry) -> Void)?
    var tmuxSessions: [TmuxLaunch.Session] = []
    var tmuxAttachedHere: Set<String> = []
    var tmuxAvailable: Bool = false
    var onAttachTmux: ((String) -> Void)?
    var onKillTmux: ((String) -> Void)?
    var onAttachOrCreateTmux: (() -> Void)?
    var onNewNamedTmux: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HerminalDesign.Palette.divider)
            ScrollView {
                VStack(alignment: .leading, spacing: HerminalDesign.Spacing.sm) {
                    if agents.isEmpty {
                        emptyState
                    } else {
                        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xxs) {
                            ForEach(agents) { agent in
                                agentRow(agent)
                            }
                        }
                    }
                    worktreeSection
                    tmuxSection
                }
                .padding(HerminalDesign.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HerminalDesign.Palette.surfaceElevated)
    }

    private var header: some View {
        HStack(spacing: HerminalDesign.Spacing.xs) {
            Text("AGENTS")
                .font(HerminalDesign.Typography.caption)
                .tracking(HerminalDesign.Typography.headerTracking)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityAddTraits(.isHeader)
            Text("\(agents.count)")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .accessibilityLabel("\(agents.count) agent\(agents.count == 1 ? "" : "s") running")
            Spacer(minLength: 0)
            headerButton("plus", label: "New agent pane", action: onNewAgent)
            headerButton("square.stack.3d.up", label: "New agent worktree", action: onNewWorktree)
            headerButton("arrow.triangle.branch", label: "Open lazygit", action: onOpenLazygit)
        }
        // PanelChrome.rail keeps this title on the same leading rail as the
        // rows below and as the sibling panels that share this slot.
        .padding(.horizontal, PanelChrome.rail)
        .frame(height: TabBarView.barHeight)
    }

    /// One hairline construction for every per-row separator in this panel.
    private var rowDivider: some View {
        HerminalDesign.Palette.divider.frame(height: 1)
    }

    /// Section title plus an optional trailing shortcut chip.
    ///
    /// The horizontal inset matches the rows' own padding so titles, status
    /// dots and note text all share one leading rail — without it headers
    /// sat 8 pt to the left of every row and the panel read as ragged.
    /// `chipLabel == nil` hides the chip from assistive tech, for cases
    /// where the panel header already exposes the same action.
    private func sectionHeader(
        _ title: String,
        chip: String,
        chipLabel: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack {
            Text(title)
                .font(HerminalDesign.Typography.caption)
                .tracking(HerminalDesign.Typography.headerTracking)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button { action?() } label: {
                Text(chip)
                    .font(HerminalDesign.Typography.monoCaption)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
                    .padding(.horizontal, HerminalDesign.Spacing.xs)
                    .padding(.vertical, HerminalDesign.Spacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                            .fill(HerminalDesign.Palette.surfaceOverlay)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(action == nil)
            .accessibilityLabel(chipLabel ?? "")
            .accessibilityHidden(chipLabel == nil)
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .padding(.top, HerminalDesign.Spacing.xs)
    }

    /// Tertiary explanatory line under a section header, on the same rail.
    private func sectionNote(_ text: String) -> some View {
        Text(text)
            .font(HerminalDesign.Typography.caption)
            .foregroundStyle(HerminalDesign.Palette.textTertiary)
            .padding(.horizontal, HerminalDesign.Spacing.sm)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func headerButton(_ systemName: String, label: String, action: (() -> Void)?) -> some View {
        Button(action: { action?() }) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel(label)
    }

    private var emptyState: some View {
        PanelChrome.emptyState(
            "No agents running",
            "⌘⌥A splits a Claude pane. ⌘⌥W spins an isolated worktree."
        )
    }

    // v1.0 polish: rows read as a flat list with hairline dividers and the
    // pane chip on the trailing edge — matches the launch-site hero mockup.
    private func agentRow(_ agent: DetectedAgent) -> some View {
        HStack(spacing: HerminalDesign.Spacing.sm) {
            Circle()
                .fill(Self.color(for: agent.status))
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.label(for: agent.kind))
                    .font(HerminalDesign.Typography.bodyEmphasis)
                    .foregroundStyle(HerminalDesign.Palette.textPrimary)
                Text("pid \(agent.pid) · \(Self.statusText(agent.status))")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textTertiary)
            }
            Spacer(minLength: 0)
            if let tab = agent.tabHint {
                // AgentPaneMapper returns a flattened session/pane
                // index, not a tab-strip index. Number it 1-based.
                // Neutral chip: this is locator metadata, so it must not
                // out-shout the agent name next to it.
                Text("Pane \(tab + 1)")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
                    .padding(.horizontal, HerminalDesign.Spacing.xs)
                    .padding(.vertical, HerminalDesign.Spacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                            .fill(HerminalDesign.Palette.surfaceOverlay)
                    )
            }
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .padding(.vertical, HerminalDesign.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { rowDivider }
        .contentShape(Rectangle())
        .onTapGesture { onSelectAgent?(agent) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.a11yLabel(for: agent))
        .accessibilityAddTraits(.isButton)
    }

    private var worktreeSection: some View {
        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xxs) {
            // chipLabel nil: the panel header's square.stack.3d.up button
            // already exposes onNewWorktree, and a second identically
            // labelled control would read as a duplicate in VoiceOver.
            sectionHeader("WORKTREES", chip: "⌘⌥W", chipLabel: nil, action: onNewWorktree)
            if !inGitRepo {
                sectionNote("Current pane is not a git repo")
            } else if worktrees.isEmpty {
                sectionNote("No worktrees")
            } else {
                ForEach(worktrees) { tree in
                    worktreeRow(tree)
                }
            }
        }
    }

    private func worktreeRow(_ tree: GitWorktree.Entry) -> some View {
        HStack(spacing: HerminalDesign.Spacing.xs) {
            // Glyph lives inside the button so the row's leading edge is
            // part of the click target, not a dead zone.
            Button { onOpenWorktree?(tree) } label: {
                HStack(spacing: HerminalDesign.Spacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(HerminalDesign.Palette.accent)
                        .accessibilityHidden(true)
                    worktreeRowText(tree)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open worktree \(tree.label)")
            tinyButton("sparkles", label: "Open Claude in \(tree.label)") {
                onAgentInWorktree?(tree)
            }
            if !GitWorktree.pathsEqual(tree.path, primaryWorktreePath) {
                tinyButton("trash", label: "Remove worktree \(tree.label)") {
                    onRemoveWorktree?(tree)
                }
            }
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .padding(.vertical, HerminalDesign.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { rowDivider }
    }

    private func worktreeRowText(_ tree: GitWorktree.Entry) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(tree.label)
                .font(HerminalDesign.Typography.bodyEmphasis)
                .foregroundStyle(HerminalDesign.Palette.textPrimary)
                .lineLimit(1)
            Text((tree.path as NSString).lastPathComponent)
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .lineLimit(1)
        }
    }

    private var tmuxSection: some View {
        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xxs) {
            tmuxSectionHeader
            if !tmuxAvailable {
                sectionNote("tmux is not installed")
            } else if tmuxSessions.isEmpty {
                sectionNote("No tmux sessions")
            } else {
                ForEach(tmuxSessions) { session in
                    tmuxRow(session)
                }
            }
        }
    }

    private var tmuxSectionHeader: some View {
        HStack {
            Text("TMUX")
                .font(HerminalDesign.Typography.caption)
                .tracking(HerminalDesign.Typography.headerTracking)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            headerChip(
                "New",
                label: "Attach or create tmux session",
                action: onAttachOrCreateTmux
            )
            headerChip(
                "Named…",
                label: "New named tmux session",
                action: onNewNamedTmux
            )
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .padding(.top, HerminalDesign.Spacing.xs)
    }

    private func headerChip(_ title: String, label: String, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            Text(title)
                .font(HerminalDesign.Typography.monoCaption)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .padding(.horizontal, HerminalDesign.Spacing.xs)
                .padding(.vertical, HerminalDesign.Spacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                        .fill(HerminalDesign.Palette.surfaceOverlay)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel(label)
    }

    private func tmuxRow(_ session: TmuxLaunch.Session) -> some View {
        let openHere = tmuxAttachedHere.contains(session.name)
        return HStack(spacing: HerminalDesign.Spacing.xs) {
            Image(systemName: "square.split.2x1")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HerminalDesign.Palette.accent)
                .accessibilityHidden(true)
            Button { onAttachTmux?(session.name) } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.name)
                        .font(HerminalDesign.Typography.bodyEmphasis)
                        .foregroundStyle(HerminalDesign.Palette.textPrimary)
                        .lineLimit(1)
                    Text(TmuxLaunch.statusLine(session))
                        .font(HerminalDesign.Typography.caption)
                        .foregroundStyle(HerminalDesign.Palette.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Self.tmuxA11yLabel(session, openHere: openHere))
            if openHere {
                Text("Here")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.accent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, HerminalDesign.Spacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(HerminalDesign.Palette.accent.opacity(0.15))
                    )
                    .accessibilityHidden(true)
            }
            tinyButton("trash", label: "Kill tmux session \(session.name)") {
                onKillTmux?(session.name)
            }
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .padding(.vertical, HerminalDesign.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { rowDivider }
    }

    private func tinyButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private static func tmuxA11yLabel(_ session: TmuxLaunch.Session, openHere: Bool) -> String {
        var label = "Attach tmux session \(session.name), \(TmuxLaunch.statusLine(session))"
        if openHere { label += ", open in this window" }
        return label
    }

    private static func a11yLabel(for agent: DetectedAgent) -> String {
        let base = "\(label(for: agent.kind)) agent \(statusText(agent.status)), pid \(agent.pid)"
        if let tab = agent.tabHint {
            return "\(base), in pane \(tab + 1)"
        }
        return base
    }

    private static func color(for status: AgentStatus) -> Color {
        switch status {
        case .running: HerminalDesign.Palette.statusRunning
        case .idle: HerminalDesign.Palette.statusIdle
        case .needsInput: HerminalDesign.Palette.statusNeedsInput
        case .exitedSuccess: HerminalDesign.Palette.statusDone
        case .exitedError: HerminalDesign.Palette.statusError
        case .unknown: HerminalDesign.Palette.statusIdle
        }
    }

    private static func statusText(_ status: AgentStatus) -> String {
        switch status {
        case .running: "running"
        case .idle: "idle"
        case .needsInput: "needs input"
        case .exitedSuccess: "done"
        case .exitedError: "error"
        case .unknown: "starting"
        }
    }

    private static func label(for kind: AgentKind) -> String {
        switch kind {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .aider: "Aider"
        case .unknown: "Agent"
        }
    }
}
