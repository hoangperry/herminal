import AppKit
import SwiftUI
import HerminalAgent
import HerminalDB

enum SidebarFilterQuery {
    static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isActive(_ query: String) -> Bool {
        !normalized(query).isEmpty
    }

    static func matches(_ query: String, fields: [String?]) -> Bool {
        let needle = normalized(query)
        guard !needle.isEmpty else { return true }
        return fields.compactMap { $0 }.contains { field in
            field.range(
                of: needle,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            ) != nil
        }
    }
}

@MainActor
final class SidebarFilterState: ObservableObject {
    @Published var sshHostsQuery = ""
    @Published var claudeSessionsQuery = ""
    @Published var agentDashboardQuery = ""
    @Published var sshReturnFocusHostID: UUID?

    func prepareForSavedHost(_ host: SSHHost) {
        sshReturnFocusHostID = host.id
        if SSHHostsFilterPolicy.filtered([host], query: sshHostsQuery).isEmpty {
            sshHostsQuery = ""
        }
    }
}

enum SidebarFilterFocusPolicy {
    static func shouldApply(
        requestID: UUID?,
        appliedRequestID: UUID?
    ) -> Bool {
        guard let requestID else { return false }
        return requestID != appliedRequestID
    }

    static func remainingRequest(
        currentRequestID: UUID?,
        appliedRequestID: UUID
    ) -> UUID? {
        currentRequestID == appliedRequestID ? nil : currentRequestID
    }
}

enum SidebarInteractiveChrome {
    static func shouldAnimate(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}

enum SidebarFilterAnnouncementPolicy {
    static func shouldAnnounceResult(
        previousQuery: String,
        newQuery: String,
        previousAnnouncement: String?,
        newAnnouncement: String
    ) -> Bool {
        SidebarFilterQuery.normalized(previousQuery)
            != SidebarFilterQuery.normalized(newQuery)
            && previousAnnouncement != newAnnouncement
    }
}

enum SSHHostsFilterPolicy {
    static func filtered(_ hosts: [SSHHost], query: String) -> [SSHHost] {
        hosts.filter { host in
            SidebarFilterQuery.matches(
                query,
                fields: [host.nickname, host.hostname, host.user, String(host.port)]
            )
        }
    }

    static func countLabel(visible: Int, total: Int, isFiltering: Bool) -> String {
        isFiltering ? "\(visible)/\(total)" : "\(total)"
    }

    static func countAccessibilityLabel(
        visible: Int,
        total: Int,
        isFiltering: Bool
    ) -> String {
        guard isFiltering else {
            return "\(total) saved SSH host\(total == 1 ? "" : "s")"
        }
        return "Showing \(visible) of \(total) saved SSH hosts"
    }

    static func resultAccessibilityAnnouncement(
        visible: Int,
        total: Int,
        isFiltering: Bool
    ) -> String {
        let count = countAccessibilityLabel(
            visible: visible,
            total: total,
            isFiltering: isFiltering
        )
        guard isFiltering, visible == 0 else { return count }
        return "No matching SSH hosts. \(count)"
    }

    static func showsNoMatches(total: Int, visible: Int, query: String) -> Bool {
        total > 0 && visible == 0 && SidebarFilterQuery.isActive(query)
    }
}

enum ClaudeSessionsFilterPolicy {
    static func filtered(
        _ sessions: [ClaudeProjectSession],
        query: String
    ) -> [ClaudeProjectSession] {
        sessions.filter { session in
            SidebarFilterQuery.matches(
                query,
                fields: [session.projectName, session.cwd, session.gitBranch]
            )
        }
    }

    static func countLabel(visible: Int, total: Int, isFiltering: Bool) -> String {
        isFiltering ? "\(visible)/\(total)" : "\(total)"
    }

    static func countAccessibilityLabel(
        visible: Int,
        total: Int,
        isFiltering: Bool
    ) -> String {
        guard isFiltering else {
            return "\(total) Claude session\(total == 1 ? "" : "s")"
        }
        return "Showing \(visible) of \(total) Claude sessions"
    }

    static func resultAccessibilityAnnouncement(
        visible: Int,
        total: Int,
        isFiltering: Bool
    ) -> String {
        let count = countAccessibilityLabel(
            visible: visible,
            total: total,
            isFiltering: isFiltering
        )
        guard isFiltering, visible == 0 else { return count }
        return "No matching Claude sessions. \(count)"
    }

    static func showsNoMatches(total: Int, visible: Int, query: String) -> Bool {
        total > 0 && visible == 0 && SidebarFilterQuery.isActive(query)
    }
}

enum AgentDashboardFilterPolicy {
    static func filtered(_ agents: [DetectedAgent], query: String) -> [DetectedAgent] {
        agents.filter { agent in
            SidebarFilterQuery.matches(
                query,
                fields: [
                    kindLabel(agent.kind),
                    agent.processName,
                    statusLabel(agent.status),
                    agent.tabHint.map { "Pane \($0 + 1)" }
                ]
            )
        }
    }

    static func countLabel(visible: Int, total: Int, isFiltering: Bool) -> String {
        isFiltering ? "\(visible)/\(total)" : "\(total)"
    }

    static func countAccessibilityLabel(
        visible: Int,
        total: Int,
        isFiltering: Bool
    ) -> String {
        guard isFiltering else { return "\(total) agent\(total == 1 ? "" : "s")" }
        return "Showing \(visible) of \(total) agents"
    }

    static func resultAccessibilityAnnouncement(
        visible: Int,
        total: Int,
        isFiltering: Bool
    ) -> String {
        let count = countAccessibilityLabel(
            visible: visible,
            total: total,
            isFiltering: isFiltering
        )
        guard isFiltering, visible == 0 else { return count }
        return "No matching agents. \(count)"
    }

    static func showsNoMatches(total: Int, visible: Int, query: String) -> Bool {
        total > 0 && visible == 0 && SidebarFilterQuery.isActive(query)
    }

    private static func kindLabel(_ kind: AgentKind) -> String {
        switch kind {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .aider: "Aider"
        case .unknown: "Agent"
        }
    }

    private static func statusLabel(_ status: AgentStatus) -> String {
        switch status {
        case .running: "running"
        case .idle: "idle"
        case .needsInput: "needs input"
        case .exitedSuccess: "done"
        case .exitedError: "error"
        case .unknown: "starting"
        }
    }
}

struct SidebarFilterField: View {
    @Binding var query: String
    let prompt: String
    let accessibilityLabel: String
    let accessibilityHint: String
    let clearAccessibilityLabel: String
    let requestsInitialFocus: Bool
    let focusRequestID: UUID?
    let resultAnnouncement: String
    let onFocusRequestApplied: (UUID) -> Void
    let onInitialFocusApplied: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isClearHovered = false
    @State private var appliedFocusRequestID: UUID?
    @State private var lastAnnouncedResultAnnouncement: String?

    var body: some View {
        HStack(spacing: HerminalDesign.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityHidden(true)

            TextField(prompt, text: $query)
                .textFieldStyle(.plain)
                .font(HerminalDesign.Typography.body)
                .focused($isFocused)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint(accessibilityHint)

            if SidebarFilterQuery.isActive(query) {
                Button {
                    query = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(
                            isClearHovered
                                ? HerminalDesign.Palette.textPrimary
                                : HerminalDesign.Palette.textSecondary
                        )
                        .frame(
                            width: PanelChrome.compactInteractiveControlSize,
                            height: PanelChrome.compactInteractiveControlSize
                        )
                }
                .buttonStyle(.plain)
                .onHover { isClearHovered = $0 }
                .accessibilityLabel(clearAccessibilityLabel)
                .accessibilityHint("Clears the filter and shows every item")
            }
        }
        .padding(.leading, HerminalDesign.Spacing.sm)
        .padding(.trailing, HerminalDesign.Spacing.xxs)
        .frame(minHeight: HerminalDesign.Geometry.minimumInteractiveControlSize)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(HerminalDesign.Palette.surfaceOverlay)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    isFocused
                        ? HerminalDesign.Palette.accent
                        : HerminalDesign.Palette.divider,
                    lineWidth: 1
                )
        )
        .onAppear {
            if requestsInitialFocus {
                DispatchQueue.main.async {
                    isFocused = true
                    onInitialFocusApplied()
                }
            }
            applyFocusRequestIfNeeded()
        }
        .onChange(of: focusRequestID) { _, _ in
            applyFocusRequestIfNeeded()
        }
        .onChange(of: query) { oldValue, newValue in
            guard SidebarFilterAnnouncementPolicy.shouldAnnounceResult(
                previousQuery: oldValue,
                newQuery: newValue,
                previousAnnouncement: lastAnnouncedResultAnnouncement,
                newAnnouncement: resultAnnouncement
            ) else { return }
            lastAnnouncedResultAnnouncement = resultAnnouncement
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: resultAnnouncement,
                    .priority: NSAccessibilityPriorityLevel.medium.rawValue
                ]
            )
        }
        .onExitCommand {
            guard SidebarFilterQuery.isActive(query) else { return }
            query = ""
        }
    }

    private func applyFocusRequestIfNeeded() {
        guard SidebarFilterFocusPolicy.shouldApply(
            requestID: focusRequestID,
            appliedRequestID: appliedFocusRequestID
        ), let focusRequestID else { return }
        DispatchQueue.main.async {
            guard self.focusRequestID == focusRequestID else { return }
            isFocused = true
            appliedFocusRequestID = focusRequestID
            onFocusRequestApplied(focusRequestID)
        }
    }
}
