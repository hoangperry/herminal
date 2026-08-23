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
    static let filterAccessibilityLabel = "Filter agents"
    static let filterAccessibilityHint =
        "Filters running agents by tool, process, status, or pane"

    struct ActionAccessibilityPresentation: Equatable {
        let label: String
        let hint: String
    }

    struct PrimaryRowActionPresentation: Equatable {
        let accessibility: ActionAccessibilityPresentation
        let leadingIconSystemName: String
        let includesLeadingIconInPrimaryHitRegion: Bool
        let minimumHeight: CGFloat
    }

    static let compactInteractiveControlSize = HerminalDesign.Geometry.compactInteractiveControlSize
    static let rowActionControlSize = HerminalDesign.Geometry.minimumInteractiveControlSize
    static let rowMinimumHeight = HerminalDesign.Geometry.minimumInteractiveControlSize
    static func primaryActionAccessibilityLabel(for agent: DetectedAgent) -> String {
        AgentDashboardRow.primaryActionAccessibilityLabel(for: agent)
    }
    static func primaryActionAccessibilityValue(for agent: DetectedAgent) -> String {
        AgentDashboardRow.primaryActionAccessibilityValue(for: agent)
    }
    static let primaryActionAccessibilityHint = AgentDashboardRow.primaryActionAccessibilityHint

    static func worktreePrimaryActionPresentation(
        for tree: GitWorktree.Entry
    ) -> PrimaryRowActionPresentation {
        PrimaryRowActionPresentation(
            accessibility: .init(
                label: "Open worktree \(tree.label)",
                hint: "Press Return or Space to open this worktree"
            ),
            leadingIconSystemName: "arrow.triangle.branch",
            includesLeadingIconInPrimaryHitRegion: true,
            minimumHeight: rowMinimumHeight
        )
    }

    static func worktreeClaudeActionAccessibility(
        for tree: GitWorktree.Entry
    ) -> ActionAccessibilityPresentation {
        .init(
            label: "Open Claude in \(tree.label)",
            hint: "Opens a new Claude pane in this worktree"
        )
    }

    static func worktreeRemoveActionAccessibility(
        for tree: GitWorktree.Entry
    ) -> ActionAccessibilityPresentation {
        .init(
            label: "Remove worktree \(tree.label)",
            hint: "Removes this linked worktree checkout"
        )
    }

    static func tmuxPrimaryActionPresentation(
        for session: TmuxLaunch.Session,
        openHere: Bool
    ) -> PrimaryRowActionPresentation {
        PrimaryRowActionPresentation(
            accessibility: .init(
                label: tmuxA11yLabel(session, openHere: openHere),
                hint: "Press Return or Space to attach this tmux session"
            ),
            leadingIconSystemName: "square.split.2x1",
            includesLeadingIconInPrimaryHitRegion: true,
            minimumHeight: rowMinimumHeight
        )
    }

    static func tmuxKillActionAccessibility(
        for session: TmuxLaunch.Session
    ) -> ActionAccessibilityPresentation {
        .init(
            label: "Kill tmux session \(session.name)",
            hint: "Permanently ends this tmux session"
        )
    }
    let agents: [DetectedAgent]
    @ObservedObject var filterState: SidebarFilterState
    var initialFocusRequestID: UUID? = nil
    var worktrees: [GitWorktree.Entry] = []
    var inGitRepo: Bool = false
    var primaryWorktreePath: String? = nil
    var onInitialFocusConsumed: ((UUID) -> Void)?
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
    enum EmptyActionID: Hashable { case newAgentPane, newAgentWorktree, clearFilter }
    enum InitialFocusTarget: Equatable { case none, newAgentPane, filter, firstAgent(pid_t) }
    @State private var consumedInitialFocusRequestID: UUID?
    @State private var recoveryFilterFocusRequestID: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HerminalDesign.Palette.divider)
            if !agents.isEmpty {
                SidebarFilterField(
                    query: $filterState.agentDashboardQuery,
                    prompt: "Filter agents",
                    accessibilityLabel: Self.filterAccessibilityLabel,
                    accessibilityHint: Self.filterAccessibilityHint,
                    clearAccessibilityLabel: "Clear agent filter",
                    requestsInitialFocus: initialFocusTarget == .filter,
                    focusRequestID: recoveryFilterFocusRequestID,
                    resultAnnouncement: AgentDashboardFilterPolicy.resultAccessibilityAnnouncement(
                        visible: filteredAgents.count,
                        total: agents.count,
                        isFiltering: isFiltering
                    ),
                    onFocusRequestApplied: consumeRecoveryFilterFocusRequest,
                    onInitialFocusApplied: consumeFilterFocusRequest
                )
                .padding(.horizontal, PanelChrome.rail)
                .padding(.top, HerminalDesign.Spacing.sm)
                .padding(.bottom, HerminalDesign.Spacing.xs)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: HerminalDesign.Spacing.sm) {
                    if agents.isEmpty {
                        emptyState
                    } else if showsNoMatches {
                        noMatchesState
                    } else {
                        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xxs) {
                            ForEach(filteredAgents) { agent in
                                AgentDashboardRow(
                                    agent: agent,
                                    requestsInitialFocus: initialFocusTarget == .firstAgent(agent.id),
                                    onSelect: { onSelectAgent?(agent) },
                                    onInitialFocusApplied: { consumeFocusRequest(for: agent.id) }
                                )
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
            Text(
                AgentDashboardFilterPolicy.countLabel(
                    visible: filteredAgents.count,
                    total: agents.count,
                    isFiltering: isFiltering
                )
            )
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .accessibilityLabel(
                    AgentDashboardFilterPolicy.countAccessibilityLabel(
                        visible: filteredAgents.count,
                        total: agents.count,
                        isFiltering: isFiltering
                    )
                )
            Spacer(minLength: 0)
            headerButton("plus", label: "New agent pane", action: onNewAgent)
            if inGitRepo {
                headerButton("square.stack.3d.up", label: "New agent worktree", action: onNewWorktree)
            }
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
    /// A missing action omits the chip instead of showing an unavailable
    /// affordance.
    private func sectionHeader(
        _ title: String,
        chip: String,
        chipLabel: String,
        action: (() -> Void)?
    ) -> some View {
        HStack {
            Text(title)
                .font(HerminalDesign.Typography.caption)
                .tracking(HerminalDesign.Typography.headerTracking)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if let action {
                AgentDashboardTextButton(
                    title: chip,
                    accessibilityLabel: chipLabel,
                    action: action
                )
            }
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
        AgentDashboardIconButton(
            systemName: systemName,
            accessibilityLabel: label,
            controlSize: Self.compactInteractiveControlSize,
            action: action
        )
    }
    private var emptyState: some View {
        PanelChrome.emptyState(
            Self.emptyStateContent(inGitRepo: inGitRepo),
            initiallyFocusedActionID: initialFocusTarget == .newAgentPane ? .newAgentPane : nil
        ) { action in
            switch action {
            case .newAgentPane:
                onNewAgent?()
            case .newAgentWorktree:
                onNewWorktree?()
            case .clearFilter:
                clearFilterAndFocus()
            }
        }
        .onAppear(perform: consumeEmptyStateFocusRequest)
    }
    static func emptyStateContent(inGitRepo: Bool) -> PanelChrome.EmptyStateContent<EmptyActionID> {
        let paneAction = PanelChrome.EmptyStateAction(
            id: EmptyActionID.newAgentPane,
            title: "New Agent Pane",
            systemImage: "plus.rectangle.on.rectangle",
            accessibilityLabel: "Open a new agent pane",
            accessibilityHint: "Splits the current workspace and starts Claude in a new pane",
            prominence: .primary
        )
        let worktreeActions = inGitRepo
            ? [
                PanelChrome.EmptyStateAction(
                    id: EmptyActionID.newAgentWorktree,
                    title: "New Agent Worktree",
                    systemImage: "square.stack.3d.up",
                    accessibilityLabel: "Create a new agent worktree",
                    accessibilityHint: "Creates an isolated checkout and opens Claude there",
                    prominence: .secondary
                )
            ]
            : []

        return .init(
            headline: "No agents running",
            detail: inGitRepo
                ? "Split a Claude pane here, or branch into an isolated worktree for repo-safe experiments."
                : "Split a Claude pane here to start a fresh session in the current workspace.",
            actions: [paneAction] + worktreeActions
        )
    }

    static let noMatchesContent = PanelChrome.EmptyStateContent(
        headline: "No matching agents",
        detail: "Try another tool, process, status, or pane.",
        actions: [
            PanelChrome.EmptyStateAction(
                id: EmptyActionID.clearFilter,
                title: "Clear Filter",
                systemImage: "xmark.circle",
                accessibilityLabel: "Clear agent filter",
                accessibilityHint: "Clears the filter and shows every running agent",
                prominence: .primary
            )
        ]
    )

    private var filteredAgents: [DetectedAgent] {
        AgentDashboardFilterPolicy.filtered(
            agents,
            query: filterState.agentDashboardQuery
        )
    }

    private var isFiltering: Bool {
        !agents.isEmpty && SidebarFilterQuery.isActive(filterState.agentDashboardQuery)
    }

    private var showsNoMatches: Bool {
        AgentDashboardFilterPolicy.showsNoMatches(
            total: agents.count,
            visible: filteredAgents.count,
            query: filterState.agentDashboardQuery
        )
    }

    private var noMatchesState: some View {
        PanelChrome.emptyState(Self.noMatchesContent) { action in
            guard action == .clearFilter else { return }
            clearFilterAndFocus()
        }
    }

    private var initialFocusTarget: InitialFocusTarget {
        Self.initialFocusTarget(
            agents: agents,
            query: filterState.agentDashboardQuery,
            initialFocusRequestID: initialFocusRequestID,
            consumedInitialFocusRequestID: consumedInitialFocusRequestID
        )
    }
    static func initialFocusTarget(
        agents: [DetectedAgent],
        query: String = "",
        initialFocusRequestID: UUID?,
        consumedInitialFocusRequestID: UUID?
    ) -> InitialFocusTarget {
        guard let initialFocusRequestID,
              initialFocusRequestID != consumedInitialFocusRequestID else {
            return .none
        }
        if !agents.isEmpty, SidebarFilterQuery.isActive(query) {
            return .filter
        }
        if let agent = agents.first(where: { $0.tabHint != nil }) {
            return .firstAgent(agent.id)
        }
        return agents.isEmpty ? .newAgentPane : .none
    }
    static func retainedInitialFocusRequestID(
        _ requestID: UUID?,
        agents: [DetectedAgent],
        query: String = ""
    ) -> UUID? {
        agents.isEmpty
            || SidebarFilterQuery.isActive(query)
            || agents.contains(where: { $0.tabHint != nil })
            ? requestID
            : nil
    }
    private func consumeEmptyStateFocusRequest() {
        guard initialFocusTarget == .newAgentPane,
              let initialFocusRequestID else { return }
        DispatchQueue.main.async {
            consumedInitialFocusRequestID = initialFocusRequestID
            onInitialFocusConsumed?(initialFocusRequestID)
        }
    }
    private func consumeFocusRequest(for agentID: pid_t) {
        guard initialFocusTarget == .firstAgent(agentID),
              let initialFocusRequestID else { return }
        consumedInitialFocusRequestID = initialFocusRequestID
        onInitialFocusConsumed?(initialFocusRequestID)
    }

    private func consumeFilterFocusRequest() {
        guard initialFocusTarget == .filter,
              let initialFocusRequestID else { return }
        consumedInitialFocusRequestID = initialFocusRequestID
        onInitialFocusConsumed?(initialFocusRequestID)
    }

    private func clearFilterAndFocus() {
        filterState.agentDashboardQuery = ""
        recoveryFilterFocusRequestID = UUID()
    }

    private func consumeRecoveryFilterFocusRequest(_ requestID: UUID) {
        recoveryFilterFocusRequestID = SidebarFilterFocusPolicy.remainingRequest(
            currentRequestID: recoveryFilterFocusRequestID,
            appliedRequestID: requestID
        )
    }

    private var worktreeSection: some View {
        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xxs) {
            sectionHeader(
                "WORKTREES",
                chip: "⌘⌥W",
                chipLabel: "New agent worktree",
                action: inGitRepo ? onNewWorktree : nil
            )
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
        let primaryPresentation = Self.worktreePrimaryActionPresentation(for: tree)
        return HStack(spacing: HerminalDesign.Spacing.xs) {
            AgentDashboardPrimaryRowButton(
                presentation: primaryPresentation,
                action: { onOpenWorktree?(tree) }
            ) {
                worktreeRowText(tree)
            }
            tinyButton(
                "sparkles",
                accessibility: Self.worktreeClaudeActionAccessibility(for: tree)
            ) {
                onAgentInWorktree?(tree)
            }
            if !GitWorktree.pathsEqual(tree.path, primaryWorktreePath) {
                tinyButton(
                    "trash",
                    accessibility: Self.worktreeRemoveActionAccessibility(for: tree)
                ) {
                    onRemoveWorktree?(tree)
                }
            }
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: Self.rowMinimumHeight, alignment: .leading)
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
        AgentDashboardTextButton(
            title: title,
            accessibilityLabel: label,
            action: action
        )
    }

    private func tmuxRow(_ session: TmuxLaunch.Session) -> some View {
        let openHere = tmuxAttachedHere.contains(session.name)
        let primaryPresentation = Self.tmuxPrimaryActionPresentation(
            for: session,
            openHere: openHere
        )
        return HStack(spacing: HerminalDesign.Spacing.xs) {
            AgentDashboardPrimaryRowButton(
                presentation: primaryPresentation,
                action: { onAttachTmux?(session.name) }
            ) {
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
            }
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
            tinyButton(
                "trash",
                accessibility: Self.tmuxKillActionAccessibility(for: session)
            ) {
                onKillTmux?(session.name)
            }
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: Self.rowMinimumHeight, alignment: .leading)
        .overlay(alignment: .bottom) { rowDivider }
    }

    private func tinyButton(
        _ systemName: String,
        accessibility: ActionAccessibilityPresentation,
        action: @escaping () -> Void
    ) -> some View {
        AgentDashboardIconButton(
            systemName: systemName,
            accessibilityLabel: accessibility.label,
            controlSize: Self.rowActionControlSize,
            accessibilityHint: accessibility.hint,
            action: action
        )
    }

    private static func tmuxA11yLabel(_ session: TmuxLaunch.Session, openHere: Bool) -> String {
        var label = "Attach tmux session \(session.name), \(TmuxLaunch.statusLine(session))"
        if openHere { label += ", open in this window" }
        return label
    }

}
