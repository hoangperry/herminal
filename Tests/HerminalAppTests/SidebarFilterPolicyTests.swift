import Foundation
import HerminalAgent
import HerminalDB
import Testing
@testable import HerminalApp

@Suite("Sidebar filter policy")
@MainActor
struct SidebarFilterPolicyTests {
    private let prodHost = SSHHost(
        nickname: "Sản xuất",
        hostname: "prod.example.com",
        user: "deploy",
        port: 22
    )
    private let stagingHost = SSHHost(
        nickname: "Staging",
        hostname: "stage.internal",
        user: "preview",
        port: 2202
    )

    private let apiSession = ClaudeProjectSession(
        sessionId: "api-session",
        cwd: "/Users/example/Projects/Café-API",
        gitBranch: "feature/payments",
        lastActive: Date(timeIntervalSince1970: 2),
        sessionCount: 3
    )
    private let webSession = ClaudeProjectSession(
        sessionId: "web-session",
        cwd: "/Users/example/Projects/web-client",
        gitBranch: nil,
        lastActive: Date(timeIntervalSince1970: 1),
        sessionCount: 1
    )
    private let claudeAgent = DetectedAgent(
        id: 41,
        kind: .claudeCode,
        processName: "claude",
        status: .running,
        tabHint: 0
    )
    private let codexAgent = DetectedAgent(
        id: 42,
        kind: .codex,
        processName: "codex",
        status: .needsInput,
        tabHint: 2
    )

    @Test("SSH filtering matches identity fields, user, and port")
    func sshFieldMatching() {
        let hosts = [prodHost, stagingHost]

        #expect(SSHHostsFilterPolicy.filtered(hosts, query: "sản").map(\.id) == [prodHost.id])
        #expect(SSHHostsFilterPolicy.filtered(hosts, query: "PROD.EXAMPLE").map(\.id) == [prodHost.id])
        #expect(SSHHostsFilterPolicy.filtered(hosts, query: "preview").map(\.id) == [stagingHost.id])
        #expect(SSHHostsFilterPolicy.filtered(hosts, query: "2202").map(\.id) == [stagingHost.id])
    }

    @Test("sidebar filtering trims input, folds diacritics, and preserves source order")
    func sharedMatchingSemantics() {
        let hosts = [prodHost, stagingHost]
        let sessions = [apiSession, webSession]

        #expect(SSHHostsFilterPolicy.filtered(hosts, query: "   ") == hosts)
        #expect(ClaudeSessionsFilterPolicy.filtered(sessions, query: " cafe ").map(\.id) == [apiSession.id])
        #expect(ClaudeSessionsFilterPolicy.filtered(sessions, query: "") == sessions)
    }

    @Test("Claude filtering matches project, cwd, and optional branch")
    func claudeFieldMatching() {
        let sessions = [apiSession, webSession]

        #expect(ClaudeSessionsFilterPolicy.filtered(sessions, query: "Café-API").map(\.id) == [apiSession.id])
        #expect(ClaudeSessionsFilterPolicy.filtered(sessions, query: "projects/web").map(\.id) == [webSession.id])
        #expect(ClaudeSessionsFilterPolicy.filtered(sessions, query: "PAYMENTS").map(\.id) == [apiSession.id])
        #expect(ClaudeSessionsFilterPolicy.filtered(sessions, query: "missing").isEmpty)
    }

    @Test("Agent filtering matches vendor, process, status, and pane")
    func agentFieldMatching() {
        let agents = [claudeAgent, codexAgent]

        #expect(
            AgentDashboardFilterPolicy.filtered(agents, query: "claude code").map(\.id)
                == [claudeAgent.id]
        )
        #expect(
            AgentDashboardFilterPolicy.filtered(agents, query: "codex").map(\.id)
                == [codexAgent.id]
        )
        #expect(
            AgentDashboardFilterPolicy.filtered(agents, query: "needs input").map(\.id)
                == [codexAgent.id]
        )
        #expect(
            AgentDashboardFilterPolicy.filtered(agents, query: "pane 1").map(\.id)
                == [claudeAgent.id]
        )
    }

    @Test("filter counts distinguish total data from visible results")
    func truthfulCounts() {
        #expect(SSHHostsFilterPolicy.countLabel(visible: 3, total: 3, isFiltering: false) == "3")
        #expect(SSHHostsFilterPolicy.countLabel(visible: 1, total: 3, isFiltering: true) == "1/3")
        #expect(
            SSHHostsFilterPolicy.countAccessibilityLabel(
                visible: 1,
                total: 3,
                isFiltering: true
            ) == "Showing 1 of 3 saved SSH hosts"
        )
        #expect(
            ClaudeSessionsFilterPolicy.countAccessibilityLabel(
                visible: 0,
                total: 4,
                isFiltering: true
            ) == "Showing 0 of 4 Claude sessions"
        )
        #expect(
            ClaudeSessionsFilterPolicy.countAccessibilityLabel(
                visible: 1,
                total: 1,
                isFiltering: false
            ) == "1 Claude session"
        )
        #expect(AgentDashboardFilterPolicy.countLabel(visible: 1, total: 2, isFiltering: true) == "1/2")
        #expect(
            AgentDashboardFilterPolicy.countAccessibilityLabel(
                visible: 1,
                total: 2,
                isFiltering: true
            ) == "Showing 1 of 2 agents"
        )
    }

    @Test("filtered result announcements distinguish matches from no matches")
    func resultAnnouncements() {
        #expect(
            SSHHostsFilterPolicy.resultAccessibilityAnnouncement(
                visible: 0,
                total: 3,
                isFiltering: true
            ) == "No matching SSH hosts. Showing 0 of 3 saved SSH hosts"
        )
        #expect(
            ClaudeSessionsFilterPolicy.resultAccessibilityAnnouncement(
                visible: 2,
                total: 4,
                isFiltering: true
            ) == "Showing 2 of 4 Claude sessions"
        )
        #expect(
            ClaudeSessionsFilterPolicy.resultAccessibilityAnnouncement(
                visible: 4,
                total: 4,
                isFiltering: false
            ) == "4 Claude sessions"
        )
        #expect(
            AgentDashboardFilterPolicy.resultAccessibilityAnnouncement(
                visible: 0,
                total: 2,
                isFiltering: true
            ) == "No matching agents. Showing 0 of 2 agents"
        )
    }

    @Test("no-match state requires both backing data and an active query")
    func noMatchSemantics() {
        #expect(SSHHostsFilterPolicy.showsNoMatches(total: 3, visible: 0, query: "missing"))
        #expect(!SSHHostsFilterPolicy.showsNoMatches(total: 0, visible: 0, query: "missing"))
        #expect(!ClaudeSessionsFilterPolicy.showsNoMatches(total: 2, visible: 0, query: "   "))
        #expect(!ClaudeSessionsFilterPolicy.showsNoMatches(total: 2, visible: 1, query: "api"))
        #expect(AgentDashboardFilterPolicy.showsNoMatches(total: 2, visible: 0, query: "codex"))
        #expect(!AgentDashboardFilterPolicy.showsNoMatches(total: 0, visible: 0, query: "codex"))
    }

    @Test("both filters expose stable VoiceOver copy and clear recovery")
    func accessibilityCopy() {
        #expect(SSHHostsPanel.filterAccessibilityLabel == "Filter SSH hosts")
        #expect(!SSHHostsPanel.filterAccessibilityHint.isEmpty)
        #expect(SSHHostsPanel.noMatchesContent.actions.map(\.id) == [.clearFilter])
        #expect(SSHHostsPanel.noMatchesContent.actions.first?.accessibilityLabel == "Clear SSH host filter")

        #expect(ClaudeSessionsPanel.filterAccessibilityLabel == "Filter Claude sessions")
        #expect(!ClaudeSessionsPanel.filterAccessibilityHint.isEmpty)
        #expect(ClaudeSessionsPanel.noMatchesContent.actions.map(\.id) == [.clearFilter])
        #expect(
            ClaudeSessionsPanel.noMatchesContent.actions.first?.accessibilityLabel
                == "Clear Claude session filter"
        )

        #expect(AgentDashboardView.filterAccessibilityLabel == "Filter agents")
        #expect(!AgentDashboardView.filterAccessibilityHint.isEmpty)
        #expect(AgentDashboardView.noMatchesContent.actions.map(\.id) == [.clearFilter])
        #expect(
            AgentDashboardView.noMatchesContent.actions.first?.accessibilityLabel
                == "Clear agent filter"
        )
    }

    @Test("controller-owned filter state survives panel rebuilds")
    func controllerOwnedStateSurvivesRebuilds() {
        let state = SidebarFilterState()
        state.sshHostsQuery = "prod"
        state.claudeSessionsQuery = "feature/payments"
        state.agentDashboardQuery = "codex"

        let rebuiltPanelState = state

        #expect(rebuiltPanelState.sshHostsQuery == "prod")
        #expect(rebuiltPanelState.claudeSessionsQuery == "feature/payments")
        #expect(rebuiltPanelState.agentDashboardQuery == "codex")
    }

    @Test("a new focus request is applied once and Reduce Motion disables emphasis animation")
    func focusAndMotionPolicy() {
        let requestID = UUID()

        #expect(
            SidebarFilterFocusPolicy.shouldApply(
                requestID: requestID,
                appliedRequestID: nil
            )
        )
        #expect(
            !SidebarFilterFocusPolicy.shouldApply(
                requestID: requestID,
                appliedRequestID: requestID
            )
        )
        #expect(!SidebarFilterFocusPolicy.shouldApply(requestID: nil, appliedRequestID: nil))
        #expect(
            SidebarFilterFocusPolicy.remainingRequest(
                currentRequestID: requestID,
                appliedRequestID: requestID
            ) == nil
        )
        let newerRequestID = UUID()
        #expect(
            SidebarFilterFocusPolicy.remainingRequest(
                currentRequestID: newerRequestID,
                appliedRequestID: requestID
            ) == newerRequestID
        )
        #expect(SidebarInteractiveChrome.shouldAnimate(reduceMotion: false))
        #expect(!SidebarInteractiveChrome.shouldAnimate(reduceMotion: true))
    }

    @Test("result announcements stay user-driven and suppress duplicate count copy")
    func announcementPolicy() {
        #expect(
            SidebarFilterAnnouncementPolicy.shouldAnnounceResult(
                previousQuery: "",
                newQuery: "codex",
                previousAnnouncement: nil,
                newAnnouncement: "Showing 1 of 2 agents"
            )
        )
        #expect(
            !SidebarFilterAnnouncementPolicy.shouldAnnounceResult(
                previousQuery: "codex",
                newQuery: "codex",
                previousAnnouncement: "Showing 1 of 2 agents",
                newAnnouncement: "Showing 0 of 3 agents"
            )
        )
        #expect(
            !SidebarFilterAnnouncementPolicy.shouldAnnounceResult(
                previousQuery: "codex",
                newQuery: " codex ",
                previousAnnouncement: "Showing 1 of 2 agents",
                newAnnouncement: "Showing 1 of 2 agents"
            )
        )
        #expect(
            !SidebarFilterAnnouncementPolicy.shouldAnnounceResult(
                previousQuery: "c",
                newQuery: "co",
                previousAnnouncement: "Showing 1 of 2 agents",
                newAnnouncement: "Showing 1 of 2 agents"
            )
        )
    }

    @Test("saving an SSH host preserves a matching filter and restores its row")
    func savedHostFocusState() {
        let state = SidebarFilterState()
        state.sshHostsQuery = "prod"

        state.prepareForSavedHost(prodHost)

        #expect(state.sshHostsQuery == "prod")
        #expect(state.sshReturnFocusHostID == prodHost.id)
    }

    @Test("saving a hidden SSH host clears the filter before restoring its row")
    func hiddenSavedHostRecovery() {
        let state = SidebarFilterState()
        state.sshHostsQuery = "legacy"

        state.prepareForSavedHost(prodHost)

        #expect(state.sshHostsQuery.isEmpty)
        #expect(state.sshReturnFocusHostID == prodHost.id)
    }
}
