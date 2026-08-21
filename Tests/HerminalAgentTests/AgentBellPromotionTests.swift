// Covers AgentPaneMapper.promoteOnBell — the bell → .needsInput promotion
// that drives the one status the agent dashboard exists to surface.
//
// This shipped broken. The bell set was collected per surface and then
// collapsed into a single window-global "did anything ring", so one bell in
// one pane promoted every running or idle agent and the dashboard flagged
// three agents when one wanted input. The bug survived because nothing
// watched it. These tests pin the scoping so it cannot come back quietly.

import Foundation
import Testing
@testable import HerminalAgent

@Suite("AgentBellPromotion")
struct AgentBellPromotionTests {
    /// Two tabs, one surface each: tab 0 owns surface 100, tab 1 owns 200.
    private let addressesByTab: [Int: Set<Int>] = [0: [100], 1: [200]]

    private func agent(_ pid: pid_t, _ status: AgentStatus, tab: Int?) -> DetectedAgent {
        DetectedAgent(id: pid, kind: .claudeCode, processName: "claude",
                      status: status, tabHint: tab)
    }

    // MARK: - The regression this file exists for

    @Test("a bell promotes only the agent in the tab that rang")
    func promotesOnlyTheRingingTab() {
        let agents = [agent(1, .running, tab: 0), agent(2, .running, tab: 1)]
        let out = AgentPaneMapper.promoteOnBell(
            agents, bellAddresses: [200], addressesByTab: addressesByTab
        )
        // Tab 0 was silent. Under the old any-bell logic this was .needsInput.
        #expect(out[0].status == .running)
        #expect(out[1].status == .needsInput)
    }

    @Test("both agents promote when both tabs ring")
    func everyRingingTabPromotes() {
        let agents = [agent(1, .idle, tab: 0), agent(2, .running, tab: 1)]
        let out = AgentPaneMapper.promoteOnBell(
            agents, bellAddresses: [100, 200], addressesByTab: addressesByTab
        )
        #expect(out.allSatisfy { $0.status == .needsInput })
    }

    @Test("a bell from a surface belonging to no known tab promotes nothing")
    func bellFromAnUnmappedSurface() {
        let out = AgentPaneMapper.promoteOnBell(
            [agent(1, .running, tab: 0)],
            bellAddresses: [999],
            addressesByTab: addressesByTab
        )
        #expect(out[0].status == .running)
    }

    // MARK: - The deliberate backstop

    @Test("an agent the mapper could not place falls back to any-bell")
    func nilTabHintOverFlags() {
        // tabHint nil means annotate() failed to pair it with a tab. Better
        // to over-flag than to hide a stalled agent.
        let out = AgentPaneMapper.promoteOnBell(
            [agent(1, .running, tab: nil)],
            bellAddresses: [200],
            addressesByTab: addressesByTab
        )
        #expect(out[0].status == .needsInput)
    }

    // MARK: - Eligibility and no-ops

    @Test("no bell anywhere leaves every agent untouched")
    func noBellIsANoOp() {
        let agents = [agent(1, .running, tab: 0), agent(2, .idle, tab: nil)]
        let out = AgentPaneMapper.promoteOnBell(
            agents, bellAddresses: [], addressesByTab: addressesByTab
        )
        #expect(out == agents)
    }

    @Test("only idle and running are eligible for promotion",
          arguments: [AgentStatus.exitedSuccess, .exitedError, .needsInput, .unknown])
    func ineligibleStatusesSurviveTheBell(status: AgentStatus) {
        // A finished agent must not be dragged back to a live-looking state
        // by a neighbour's bell.
        let out = AgentPaneMapper.promoteOnBell(
            [agent(1, status, tab: 1)],
            bellAddresses: [200],
            addressesByTab: addressesByTab
        )
        #expect(out[0].status == status)
    }

    @Test("promotion preserves identity, kind and tab placement")
    func promotionOnlyChangesStatus() {
        let before = agent(4327, .running, tab: 1)
        let out = AgentPaneMapper.promoteOnBell(
            [before], bellAddresses: [200], addressesByTab: addressesByTab
        )
        #expect(out[0].id == before.id)
        #expect(out[0].kind == before.kind)
        #expect(out[0].processName == before.processName)
        #expect(out[0].tabHint == before.tabHint)
        #expect(out[0].status == .needsInput)
    }

    @Test("agent order is preserved")
    func orderIsStable() {
        let agents = [agent(3, .running, tab: 1), agent(1, .running, tab: 0), agent(2, .idle, tab: 1)]
        let out = AgentPaneMapper.promoteOnBell(
            agents, bellAddresses: [200], addressesByTab: addressesByTab
        )
        #expect(out.map(\.id) == [3, 1, 2])
    }

    @Test("an empty agent list is handled")
    func emptyInput() {
        let out = AgentPaneMapper.promoteOnBell(
            [], bellAddresses: [200], addressesByTab: addressesByTab
        )
        #expect(out.isEmpty)
    }

    @Test("a multi-pane tab promotes when any of its panes rings")
    func anyPaneInTheTabCounts() {
        // Tab 0 has two panes; only the second one rang.
        let byTab: [Int: Set<Int>] = [0: [100, 101]]
        let out = AgentPaneMapper.promoteOnBell(
            [agent(1, .running, tab: 0)],
            bellAddresses: [101],
            addressesByTab: byTab
        )
        #expect(out[0].status == .needsInput)
    }
}
