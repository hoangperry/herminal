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
    static let rowActionControlSize = HerminalDesign.Geometry.minimumInteractiveControlSize
    static let headerControlSize = HerminalDesign.Geometry.compactInteractiveControlSize

    let sessions: [ClaudeProjectSession]
    @ObservedObject var filterState: SidebarFilterState
    let initialFocusRequestID: UUID?
    /// Resume the project's newest conversation in its cwd.
    let onResume: (ClaudeProjectSession) -> Void
    /// Open a plain shell in the project's cwd (no claude).
    let onOpenShell: (ClaudeProjectSession) -> Void
    let onNewAgentPane: () -> Void
    let onRefresh: () -> Void

    enum EmptyActionID: Hashable {
        case newAgentPane
        case refresh
        case clearFilter
    }

    enum InitialFocusTarget: Equatable {
        case none
        case newAgentPane
        case filter
    }

    @State private var consumedInitialFocusRequestID: UUID?
    @State private var recoveryFilterFocusRequestID: UUID?

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
        PanelChrome.header("CLAUDE SESSIONS") {
            Text(
                ClaudeSessionsFilterPolicy.countLabel(
                    visible: filteredSessions.count,
                    total: sessions.count,
                    isFiltering: isFiltering
                )
            )
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .accessibilityLabel(
                    ClaudeSessionsFilterPolicy.countAccessibilityLabel(
                        visible: filteredSessions.count,
                        total: sessions.count,
                        isFiltering: isFiltering
                    )
                )
            RefreshButton(action: onRefresh)
        }
    }

    static func countAccessibilityLabel(_ count: Int) -> String {
        "\(count) Claude session\(count == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var content: some View {
        if sessions.isEmpty {
            PanelChrome.emptyState(
                Self.emptyStateContent,
                initiallyFocusedActionID: initialFocusTarget == .newAgentPane
                    ? .newAgentPane
                    : nil
            ) { action in
                switch action {
                case .newAgentPane:
                    onNewAgentPane()
                case .refresh:
                    onRefresh()
                case .clearFilter:
                    filterState.claudeSessionsQuery = ""
                }
            }
            .onAppear(perform: consumeEmptyStateFocusRequest)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                SidebarFilterField(
                    query: $filterState.claudeSessionsQuery,
                    prompt: "Filter sessions",
                    accessibilityLabel: Self.filterAccessibilityLabel,
                    accessibilityHint: Self.filterAccessibilityHint,
                    clearAccessibilityLabel: "Clear Claude session filter",
                    requestsInitialFocus: initialFocusTarget == .filter,
                    focusRequestID: recoveryFilterFocusRequestID,
                    resultAnnouncement: ClaudeSessionsFilterPolicy.resultAccessibilityAnnouncement(
                        visible: filteredSessions.count,
                        total: sessions.count,
                        isFiltering: isFiltering
                    ),
                    onFocusRequestApplied: consumeRecoveryFilterFocusRequest,
                    onInitialFocusApplied: consumeFilterFocusRequest
                )
                .padding(.horizontal, HerminalDesign.Spacing.sm)
                .padding(.top, HerminalDesign.Spacing.sm)
                .padding(.bottom, HerminalDesign.Spacing.xs)

                if showsNoMatches {
                    PanelChrome.emptyState(Self.noMatchesContent) { action in
                        guard action == .clearFilter else { return }
                        clearFilterAndFocus()
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xxs) {
                            ForEach(filteredSessions) { session in
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
        }
    }

    private var filteredSessions: [ClaudeProjectSession] {
        ClaudeSessionsFilterPolicy.filtered(
            sessions,
            query: filterState.claudeSessionsQuery
        )
    }

    private var isFiltering: Bool {
        !sessions.isEmpty && SidebarFilterQuery.isActive(filterState.claudeSessionsQuery)
    }

    private var showsNoMatches: Bool {
        ClaudeSessionsFilterPolicy.showsNoMatches(
            total: sessions.count,
            visible: filteredSessions.count,
            query: filterState.claudeSessionsQuery
        )
    }

    private var initialFocusTarget: InitialFocusTarget {
        Self.initialFocusTarget(
            sessions: sessions,
            initialFocusRequestID: initialFocusRequestID,
            consumedInitialFocusRequestID: consumedInitialFocusRequestID
        )
    }

    static func initialFocusTarget(
        sessions: [ClaudeProjectSession],
        initialFocusRequestID: UUID?,
        consumedInitialFocusRequestID: UUID?
    ) -> InitialFocusTarget {
        guard let initialFocusRequestID,
              initialFocusRequestID != consumedInitialFocusRequestID else {
            return .none
        }
        return sessions.isEmpty ? .newAgentPane : .filter
    }

    private func consumeEmptyStateFocusRequest() {
        guard initialFocusTarget == .newAgentPane,
              let initialFocusRequestID else { return }
        DispatchQueue.main.async {
            consumedInitialFocusRequestID = initialFocusRequestID
        }
    }

    private func consumeFilterFocusRequest() {
        guard initialFocusTarget == .filter,
              let initialFocusRequestID else { return }
        consumedInitialFocusRequestID = initialFocusRequestID
    }

    private func clearFilterAndFocus() {
        filterState.claudeSessionsQuery = ""
        recoveryFilterFocusRequestID = UUID()
    }

    private func consumeRecoveryFilterFocusRequest(_ requestID: UUID) {
        recoveryFilterFocusRequestID = SidebarFilterFocusPolicy.remainingRequest(
            currentRequestID: recoveryFilterFocusRequestID,
            appliedRequestID: requestID
        )
    }

    static let filterAccessibilityLabel = "Filter Claude sessions"
    static let filterAccessibilityHint = "Filters sessions by project name, path, or Git branch"

    static let noMatchesContent = PanelChrome.EmptyStateContent(
        headline: "No matching Claude sessions",
        detail: "Try another project name, path, or Git branch.",
        actions: [
            PanelChrome.EmptyStateAction(
                id: EmptyActionID.clearFilter,
                title: "Clear Filter",
                systemImage: "xmark.circle",
                accessibilityLabel: "Clear Claude session filter",
                accessibilityHint: "Clears the filter and shows every Claude session",
                prominence: .primary
            )
        ]
    )

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    static func relative(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    static func primaryActionAccessibilityLabel(for session: ClaudeProjectSession) -> String {
        "Resume Claude in \(session.projectName)"
    }

    static let primaryActionAccessibilityHint = "Press Return or Space to resume Claude"

    static func actionsAccessibilityLabel(for session: ClaudeProjectSession) -> String {
        "Actions for Claude session \(session.projectName)"
    }

    static let actionsAccessibilityHint = "Opens session actions including Open Shell Here"

    static let emptyStateContent = PanelChrome.EmptyStateContent(
        headline: "No Claude sessions found",
        detail: "Start a new Claude pane here, or refresh after you run `claude` in another project.",
        actions: [
            PanelChrome.EmptyStateAction(
                id: EmptyActionID.newAgentPane,
                title: "New Agent Pane",
                systemImage: "plus.rectangle.on.rectangle",
                accessibilityLabel: "Open a new agent pane",
                accessibilityHint: "Splits the current workspace and starts Claude in a new pane",
                prominence: .primary
            ),
            PanelChrome.EmptyStateAction(
                id: EmptyActionID.refresh,
                title: "Refresh",
                systemImage: "arrow.clockwise",
                accessibilityLabel: "Refresh Claude session list",
                accessibilityHint: "Rescans your local Claude projects for resumable sessions",
                prominence: .secondary
            )
        ]
    )
}

private struct ClaudeSessionRow: View {
    let session: ClaudeProjectSession
    let onResume: () -> Void
    let onOpenShell: () -> Void

    @State private var isHovered = false
    @FocusState private var isPrimaryFocused: Bool
    @FocusState private var isActionsFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEmphasized: Bool {
        isHovered || isPrimaryFocused || isActionsFocused
    }

    var body: some View {
        HStack(spacing: HerminalDesign.Spacing.xs) {
            Button(action: onResume) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(session.projectName)
                            .font(HerminalDesign.Typography.bodyEmphasis)
                            .foregroundStyle(HerminalDesign.Palette.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
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
                        Spacer(minLength: 0)
                        Text(ClaudeSessionsPanel.relative(session.lastActive))
                            .font(HerminalDesign.Typography.caption)
                            .foregroundStyle(HerminalDesign.Palette.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($isPrimaryFocused)
            .accessibilityLabel(ClaudeSessionsPanel.primaryActionAccessibilityLabel(for: session))
            .accessibilityHint(ClaudeSessionsPanel.primaryActionAccessibilityHint)

            Menu {
                Button("Resume Claude", action: onResume)
                Button("Open Shell Here", action: onOpenShell)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        isActionsFocused
                            ? HerminalDesign.Palette.accent
                            : HerminalDesign.Palette.textSecondary
                    )
                    .frame(
                        width: ClaudeSessionsPanel.rowActionControlSize,
                        height: ClaudeSessionsPanel.rowActionControlSize
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                isActionsFocused
                                    ? HerminalDesign.Palette.surfaceOverlay
                                    : Color.clear
                            )
                    )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .focused($isActionsFocused)
            .accessibilityLabel(ClaudeSessionsPanel.actionsAccessibilityLabel(for: session))
            .accessibilityHint(ClaudeSessionsPanel.actionsAccessibilityHint)
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .padding(.vertical, HerminalDesign.Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .fill(isEmphasized
                      ? HerminalDesign.Palette.surfaceOverlay.opacity(1.3)
                      : HerminalDesign.Palette.surfaceOverlay)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .strokeBorder(
                    isEmphasized
                        ? HerminalDesign.Palette.accent.opacity(0.45)
                        : Color.clear,
                    lineWidth: 1
                )
        )
        .onHover { isHovered = $0 }
        .animation(
            SidebarInteractiveChrome.shouldAnimate(reduceMotion: reduceMotion)
                ? .easeOut(duration: HerminalDesign.Motion.fast)
                : nil,
            value: isEmphasized
        )
        .contextMenu {
            Button("Resume Claude", action: onResume)
            Button("Open Shell Here", action: onOpenShell)
        }
    }
}

private struct RefreshButton: View {
    let action: () -> Void
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEmphasized: Bool { isHovered || isFocused }

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isEmphasized
                                 ? HerminalDesign.Palette.accent
                                 : HerminalDesign.Palette.textSecondary)
                .frame(
                    width: ClaudeSessionsPanel.headerControlSize,
                    height: ClaudeSessionsPanel.headerControlSize
                )
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isEmphasized ? HerminalDesign.Palette.surfaceOverlay : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            isFocused ? HerminalDesign.Palette.accent.opacity(0.55) : .clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .animation(
            SidebarInteractiveChrome.shouldAnimate(reduceMotion: reduceMotion)
                ? .easeOut(duration: HerminalDesign.Motion.fast)
                : nil,
            value: isEmphasized
        )
        .accessibilityLabel("Refresh Claude session list")
    }
}
