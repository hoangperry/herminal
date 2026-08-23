import Foundation
import Testing
@testable import HerminalApp
import HerminalAgent
import HerminalDB

@Suite("Sidebar empty-state actions")
@MainActor
struct SidebarEmptyStateContentTests {
    @Test("SSH empty state exposes import before manual entry")
    func sshActions() {
        let content = SSHHostsPanel.emptyStateContent(storageIsDurable: true)

        #expect(content.actions.map(\.id) == [.importConfig, .addHost])
        #expect(content.actions.map(\.title) == ["Import ~/.ssh/config", "Add Host"])
        #expect(content.actions.first?.prominence == .primary)
        #expect(content.actions.allSatisfy(Self.hasAccessibleMetadata))
    }

    @Test("Claude empty state can start work or refresh discovery")
    func claudeActions() {
        let content = ClaudeSessionsPanel.emptyStateContent

        #expect(content.actions.map(\.id) == [.newAgentPane, .refresh])
        #expect(content.actions.map(\.title) == ["New Agent Pane", "Refresh"])
        #expect(content.actions.first?.prominence == .primary)
        #expect(content.actions.allSatisfy(Self.hasAccessibleMetadata))
    }

    @Test("Agent empty state offers the valid launch paths for the current directory")
    func agentActionsFollowGitContext() {
        let outsideRepository = AgentDashboardView.emptyStateContent(inGitRepo: false)
        let insideRepository = AgentDashboardView.emptyStateContent(inGitRepo: true)

        #expect(outsideRepository.actions.map(\.id) == [.newAgentPane])
        #expect(insideRepository.actions.map(\.id) == [.newAgentPane, .newAgentWorktree])
        #expect(insideRepository.actions.map(\.title) == ["New Agent Pane", "New Agent Worktree"])
        #expect(insideRepository.actions.first?.prominence == .primary)
        #expect(insideRepository.actions.allSatisfy(Self.hasAccessibleMetadata))
    }

    @Test("sidebar transitions honor the system Reduce Motion preference")
    func sidebarMotionPolicy() {
        #expect(WorkspaceView.shouldAnimateSidebarChange(reduceMotion: false))
        #expect(!WorkspaceView.shouldAnimateSidebarChange(reduceMotion: true))
    }

    @Test("sidebar controls keep generous row targets without overflowing compact headers")
    func panelControlTargetSizes() {
        #expect(PanelChrome.minimumInteractiveControlSize == 44)
        #expect(PanelChrome.compactInteractiveControlSize == 28)
        #expect(PanelChrome.compactInteractiveControlSize <= TabBarView.barHeight)
        #expect(SSHHostsPanel.rowActionControlSize == PanelChrome.minimumInteractiveControlSize)
        #expect(SSHHostsPanel.headerControlSize == PanelChrome.compactInteractiveControlSize)
        #expect(ClaudeSessionsPanel.rowActionControlSize == PanelChrome.minimumInteractiveControlSize)
        #expect(ClaudeSessionsPanel.headerControlSize == PanelChrome.compactInteractiveControlSize)
        #expect(SSHImportFeedback.minimumInteractiveControlSize == PanelChrome.minimumInteractiveControlSize)
        #expect(AgentDashboardView.compactInteractiveControlSize == PanelChrome.compactInteractiveControlSize)
        #expect(AgentDashboardView.rowActionControlSize == PanelChrome.minimumInteractiveControlSize)
        #expect(AgentDashboardView.rowMinimumHeight == PanelChrome.minimumInteractiveControlSize)
    }

    private static func hasAccessibleMetadata<ActionID>(
        _ action: PanelChrome.EmptyStateAction<ActionID>
    ) -> Bool {
        !action.accessibilityLabel.isEmpty && !action.accessibilityHint.isEmpty
    }
}

@Suite("SSH import feedback")
@MainActor
struct SSHImportFeedbackTests {
    @Test("import begins with a non-actionable progress announcement")
    func importingContent() {
        let content = SSHImportFeedback.importing.content(storageIsDurable: true)

        #expect(content.tone == .progress)
        #expect(content.title == "Importing SSH config…")
        #expect(content.recoveryAction == nil)
        #expect(!content.accessibilityLabel.isEmpty)
    }

    @Test("a positive import count produces singular and plural success copy")
    func importedContent() {
        let one = SSHImportFeedback.result(importedCount: 1)
        let many = SSHImportFeedback.result(importedCount: 3)
        let durable = many.content(storageIsDurable: true)
        let transient = many.content(storageIsDurable: false)

        #expect(one == .imported(count: 1))
        #expect(one.content(storageIsDurable: true).title == "Imported 1 host")
        #expect(many == .imported(count: 3))
        #expect(durable.title == "Imported 3 hosts")
        #expect(durable.detail == "Your SSH hosts are ready to connect.")
        #expect(durable.tone == .success)
        #expect(transient.detail == "Ready to connect until Herminal quits.")
    }

    @Test("an empty config explains unsupported rules and offers manual entry")
    func noConcreteHostsContent() {
        let feedback = SSHImportFeedback.result(importedCount: 0)
        let content = feedback.content(storageIsDurable: true)

        #expect(feedback == .noConcreteHosts)
        #expect(content.title == "No importable hosts found")
        #expect(content.detail.contains("Wildcard"))
        #expect(content.detail.contains("Match"))
        #expect(content.recoveryAction == .addHost)
    }

    @Test("known failures provide safe, specific recovery guidance")
    func failureContent() {
        let missing = SSHImportFeedback.configMissing.content(storageIsDurable: true)
        let tooLarge = SSHImportFeedback.fileTooLarge.content(storageIsDurable: true)
        let failed = SSHImportFeedback.failed.content(storageIsDurable: true)

        #expect(missing.title == "SSH config not found")
        #expect(missing.recoveryAction == .addHost)
        #expect(tooLarge.detail.contains("1 MB"))
        #expect(tooLarge.recoveryAction == .retry)
        #expect(failed.title == "Couldn’t import SSH config")
        #expect(failed.recoveryAction == .retry)
        #expect([missing, tooLarge, failed].allSatisfy { !$0.accessibilityLabel.isEmpty })
    }

    @Test("transient SSH storage exposes a persistent warning")
    func transientStorageNotice() {
        #expect(SSHHostsPanel.storageNoticeText(storageIsDurable: true) == nil)
        #expect(
            SSHHostsPanel.storageNoticeText(storageIsDurable: false)
                == "Saved hosts last until Herminal quits."
        )
        #expect(
            SSHHostsPanel.storageNoticeAccessibilityLabel(storageIsDurable: false)
                == "SSH host storage. Saved hosts last until Herminal quits."
        )
    }
}

@Suite("SSH import state")
struct SSHImportStateTests {
    @Test("beginning an import sets progress feedback and blocks reentry")
    func beginImport() {
        var state = SSHImportState()
        let started = state.begin()
        let startedAgain = state.begin()

        #expect(started)
        #expect(state.isImporting)
        #expect(state.feedback == .importing)
        #expect(!startedAgain)
    }

    @Test("manual host save preserves in-flight progress")
    func manualSavePreservesRunningImport() {
        var state = SSHImportState()
        let started = state.begin()
        #expect(started)

        state.clearAfterManualHostSave()

        #expect(state.isImporting)
        #expect(state.feedback == .importing)
    }

    @Test("completion clears the import gate and exposes the result")
    func completionShowsResult() {
        var state = SSHImportState()
        let started = state.begin()
        #expect(started)

        state.complete(with: .result(importedCount: 2))

        #expect(!state.isImporting)
        #expect(state.feedback == .imported(count: 2))
    }

    @Test("dismiss and manual save clear only completed feedback")
    func clearingCompletedFeedback() {
        var state = SSHImportState()
        state.complete(with: .failed)
        state.clearAfterManualHostSave()
        #expect(state.feedback == nil)

        state.complete(with: .configMissing)
        state.dismiss()
        #expect(state.feedback == nil)
    }
}

@Suite("SSH panel keyboard policy")
@MainActor
struct SSHPanelKeyboardPolicyTests {
    private let focusRequestID = UUID()
    private let host = SSHHost(
        nickname: "prod-web",
        hostname: "prod.example.com",
        user: "deploy"
    )

    @Test("an intentionally opened empty panel focuses its import action")
    func emptyPanelFocus() {
        let target = SSHHostsPanel.initialFocusTarget(
            mode: .list,
            hosts: [],
            isImporting: false,
            initialFocusRequestID: focusRequestID,
            consumedInitialFocusRequestID: nil,
            returnFocusHostID: nil
        )

        #expect(target == .importConfig)
    }

    @Test("an intentionally opened populated panel focuses its filter")
    func populatedPanelFocus() {
        let target = SSHHostsPanel.initialFocusTarget(
            mode: .list,
            hosts: [host],
            isImporting: false,
            initialFocusRequestID: focusRequestID,
            consumedInitialFocusRequestID: nil,
            returnFocusHostID: nil
        )

        #expect(target == .filter)
    }

    @Test("editing targets hostname and an active import avoids focus theft")
    func editingAndImportFocus() {
        #expect(SSHHostsPanel.initialFocusTarget(
            mode: .editing(nil),
            hosts: [],
            isImporting: false,
            initialFocusRequestID: focusRequestID,
            consumedInitialFocusRequestID: nil,
            returnFocusHostID: nil
        ) == .hostname)
        #expect(SSHHostsPanel.initialFocusTarget(
            mode: .list,
            hosts: [],
            isImporting: true,
            initialFocusRequestID: focusRequestID,
            consumedInitialFocusRequestID: nil,
            returnFocusHostID: nil
        ) == .none)
    }

    @Test("routine refreshes do not reclaim keyboard focus")
    func refreshDoesNotTakeFocus() {
        #expect(SSHHostsPanel.initialFocusTarget(
            mode: .list,
            hosts: [host],
            isImporting: false,
            initialFocusRequestID: nil,
            consumedInitialFocusRequestID: nil,
            returnFocusHostID: nil
        ) == .none)
    }

    @Test("an applied open request is one-shot and edit cancel restores its host")
    func consumedAndReturnFocus() {
        #expect(SSHHostsPanel.initialFocusTarget(
            mode: .list,
            hosts: [host],
            isImporting: false,
            initialFocusRequestID: focusRequestID,
            consumedInitialFocusRequestID: focusRequestID,
            returnFocusHostID: nil
        ) == .none)
        #expect(SSHHostsPanel.initialFocusTarget(
            mode: .list,
            hosts: [host],
            isImporting: false,
            initialFocusRequestID: focusRequestID,
            consumedInitialFocusRequestID: focusRequestID,
            returnFocusHostID: host.id
        ) == .firstHost(host.id))
    }

    @Test("host form submit eligibility ignores surrounding whitespace")
    func formSubmitEligibility() {
        #expect(!SSHHostFormView.canSubmit(hostname: ""))
        #expect(!SSHHostFormView.canSubmit(hostname: "   "))
        #expect(SSHHostFormView.canSubmit(hostname: "prod.example.com"))
    }

    @Test("Escape invokes the form cancellation path")
    func escapeCancelsForm() {
        var didCancel = false

        _ = SSHHostFormView.handleEscape {
            didCancel = true
        }

        #expect(didCancel)
    }

    @Test("every form field exposes a stable spoken label")
    func formFieldAccessibilityLabels() {
        #expect(SSHHostFormView.Field.nickname.accessibilityLabel == "Nickname")
        #expect(SSHHostFormView.Field.hostname.accessibilityLabel == "Hostname")
        #expect(SSHHostFormView.Field.user.accessibilityLabel == "User")
        #expect(SSHHostFormView.Field.port.accessibilityLabel == "Port")
    }

    @Test("validation feedback returns focus to the related field")
    func validationFeedbackFocus() {
        #expect(
            SSHHostFormView.validationPresentation(for: SSHHostError.emptyHostname)
                == .init(message: "Hostname is required.", focusedField: .hostname)
        )
        #expect(
            SSHHostFormView.validationPresentation(for: SSHHostError.invalidPort(70_000))
                == .init(
                    message: "Port 70000 is out of range (1-65535).",
                    focusedField: .port
                )
        )
    }

    @Test("non-numeric port input is rejected instead of becoming port 22")
    func invalidPortText() throws {
        #expect(try SSHHostFormView.parsedPort("") == 22)
        #expect(try SSHHostFormView.parsedPort(" 2202 ") == 2202)
        #expect(throws: SSHHostFormView.FormValidationError.invalidPortText) {
            try SSHHostFormView.parsedPort("abc")
        }
        #expect(throws: SSHHostFormView.FormValidationError.invalidPortText) {
            try SSHHostFormView.parsedPort("22x")
        }
        #expect(
            SSHHostFormView.validationPresentation(
                for: SSHHostFormView.FormValidationError.invalidPortText
            ) == .init(
                message: "Port must be a number from 1 to 65535.",
                focusedField: .port
            )
        )
    }
}

@Suite("Claude sessions keyboard policy")
@MainActor
struct ClaudeSessionsPanelKeyboardPolicyTests {
    private let focusRequestID = UUID()
    private let session = ClaudeProjectSession(
        sessionId: UUID().uuidString,
        cwd: "/tmp/herminal",
        gitBranch: "main",
        lastActive: Date(timeIntervalSince1970: 1_726_100_000),
        sessionCount: 2
    )

    @Test("an intentionally opened empty panel focuses New Agent Pane")
    func emptyPanelFocus() {
        let target = ClaudeSessionsPanel.initialFocusTarget(
            sessions: [],
            initialFocusRequestID: focusRequestID,
            consumedInitialFocusRequestID: nil
        )

        #expect(target == .newAgentPane)
    }

    @Test("an intentionally opened populated panel focuses its filter")
    func populatedPanelFocus() {
        let target = ClaudeSessionsPanel.initialFocusTarget(
            sessions: [session],
            initialFocusRequestID: focusRequestID,
            consumedInitialFocusRequestID: nil
        )

        #expect(target == .filter)
    }

    @Test("consumed requests and passive refreshes do not reclaim focus")
    func consumedAndPassiveRefresh() {
        #expect(ClaudeSessionsPanel.initialFocusTarget(
            sessions: [session],
            initialFocusRequestID: focusRequestID,
            consumedInitialFocusRequestID: focusRequestID
        ) == .none)
        #expect(ClaudeSessionsPanel.initialFocusTarget(
            sessions: [session],
            initialFocusRequestID: nil,
            consumedInitialFocusRequestID: nil
        ) == .none)
    }

    @Test("session rows expose keyboard-first resume and shell actions")
    func rowAccessibilityCopy() {
        #expect(
            ClaudeSessionsPanel.primaryActionAccessibilityLabel(for: session)
                == "Resume Claude in herminal"
        )
        #expect(
            ClaudeSessionsPanel.primaryActionAccessibilityHint
                == "Press Return or Space to resume Claude"
        )
        #expect(
            ClaudeSessionsPanel.actionsAccessibilityLabel(for: session)
                == "Actions for Claude session herminal"
        )
        #expect(
            ClaudeSessionsPanel.actionsAccessibilityHint
                == "Opens session actions including Open Shell Here"
        )
    }

    @Test("the header count has contextual VoiceOver copy")
    func countAccessibilityCopy() {
        #expect(ClaudeSessionsPanel.countAccessibilityLabel(1) == "1 Claude session")
        #expect(ClaudeSessionsPanel.countAccessibilityLabel(3) == "3 Claude sessions")
    }

    @Test("a newer passive refresh invalidates an older focus-bearing refresh")
    func refreshGateAvoidsFocusSteal() {
        var gate = WorkspaceView.ClaudePanelRefreshGate()
        let openGeneration = gate.beginRefresh()
        let passiveGeneration = gate.beginRefresh()

        #expect(!gate.shouldApply(openGeneration))
        #expect(gate.shouldApply(passiveGeneration))
    }
}

@Suite("Agent dashboard keyboard policy")
@MainActor
struct AgentDashboardKeyboardPolicyTests {
    private let focusRequestID = UUID()

    private let worktree = GitWorktree.Entry(
        path: "/tmp/herminal.worktrees/feature-api",
        head: "abc123",
        branch: "feature-api",
        isDetached: false
    )

    private let tmuxSession = TmuxLaunch.Session(
        name: "api",
        windows: 2,
        attachedClients: 1
    )

    @Test("an intentionally opened empty dashboard focuses New Agent Pane")
    func emptyDashboardFocus() {
        #expect(
            AgentDashboardView.initialFocusTarget(
                agents: [],
                initialFocusRequestID: focusRequestID,
                consumedInitialFocusRequestID: nil
            ) == .newAgentPane
        )
    }

    @Test("an intentional open focuses the first agent mapped to a pane")
    func mappedAgentFocus() {
        let mappedAgent = DetectedAgent(
            id: 42,
            kind: .claudeCode,
            processName: "claude",
            status: .running,
            tabHint: 0
        )

        #expect(
            AgentDashboardView.initialFocusTarget(
                agents: [mappedAgent],
                initialFocusRequestID: focusRequestID,
                consumedInitialFocusRequestID: nil
            ) == .firstAgent(mappedAgent.id)
        )
    }

    @Test("an intentional open with a persisted query focuses the agent filter")
    func filteredDashboardFocus() {
        let mappedAgent = DetectedAgent(
            id: 42,
            kind: .claudeCode,
            processName: "claude",
            status: .running,
            tabHint: 0
        )

        #expect(
            AgentDashboardView.initialFocusTarget(
                agents: [mappedAgent],
                query: "codex",
                initialFocusRequestID: focusRequestID,
                consumedInitialFocusRequestID: nil
            ) == .filter
        )
    }

    @Test("unmapped agents, consumed requests, and passive refreshes do not reclaim focus")
    func unavailableAndConsumedDashboardFocus() {
        let unmappedAgent = DetectedAgent(
            id: 42,
            kind: .claudeCode,
            processName: "claude",
            status: .running
        )

        #expect(AgentDashboardView.initialFocusTarget(
            agents: [unmappedAgent],
            initialFocusRequestID: focusRequestID,
            consumedInitialFocusRequestID: nil
        ) == .none)
        #expect(
            AgentDashboardView.initialFocusTarget(
                agents: [],
                initialFocusRequestID: focusRequestID,
                consumedInitialFocusRequestID: focusRequestID
            ) == .none
        )
        #expect(
            AgentDashboardView.initialFocusTarget(
                agents: [],
                initialFocusRequestID: nil,
                consumedInitialFocusRequestID: nil
            ) == .none
        )
    }

    @Test("only dashboards with a useful focus target retain the open request")
    func refreshRetainsOnlyUsefulPendingFocus() {
        let mappedAgent = DetectedAgent(
            id: 42,
            kind: .claudeCode,
            processName: "claude",
            status: .running,
            tabHint: 0
        )
        let unmappedAgent = DetectedAgent(
            id: 43,
            kind: .codex,
            processName: "codex",
            status: .running
        )

        #expect(
            AgentDashboardView.retainedInitialFocusRequestID(
                focusRequestID,
                agents: [mappedAgent]
            ) == focusRequestID
        )
        #expect(
            AgentDashboardView.retainedInitialFocusRequestID(
                focusRequestID,
                agents: [unmappedAgent]
            ) == nil
        )
        #expect(
            AgentDashboardView.retainedInitialFocusRequestID(
                focusRequestID,
                agents: [unmappedAgent],
                query: "codex"
            ) == focusRequestID
        )
        #expect(
            AgentDashboardView.retainedInitialFocusRequestID(
                focusRequestID,
                agents: []
            ) == focusRequestID
        )
    }

    @Test("mapped agent rows expose a clear keyboard action")
    func mappedAgentAccessibilityCopy() {
        let agent = DetectedAgent(
            id: 42,
            kind: .claudeCode,
            processName: "claude",
            status: .running,
            tabHint: 1
        )

        #expect(AgentDashboardView.primaryActionAccessibilityLabel(for: agent)
            == "Focus Pane 2 for Claude Code agent")
        #expect(AgentDashboardView.primaryActionAccessibilityValue(for: agent)
            == "running, pid 42")
        #expect(AgentDashboardView.primaryActionAccessibilityHint
            == "Press Return or Space to focus the mapped terminal pane")
    }

    @Test("worktree rows expose a first-class primary action")
    func worktreePrimaryPresentation() {
        #expect(
            AgentDashboardView.worktreePrimaryActionPresentation(for: worktree)
                == .init(
                    accessibility: .init(
                        label: "Open worktree feature-api",
                        hint: "Press Return or Space to open this worktree"
                    ),
                    leadingIconSystemName: "arrow.triangle.branch",
                    includesLeadingIconInPrimaryHitRegion: true,
                    minimumHeight: AgentDashboardView.rowMinimumHeight
                )
        )
    }

    @Test("worktree accessory actions explain their effect")
    func worktreeAccessoryAccessibilityCopy() {
        #expect(
            AgentDashboardView.worktreeClaudeActionAccessibility(for: worktree)
                == .init(
                    label: "Open Claude in feature-api",
                    hint: "Opens a new Claude pane in this worktree"
                )
        )
        #expect(
            AgentDashboardView.worktreeRemoveActionAccessibility(for: worktree)
                == .init(
                    label: "Remove worktree feature-api",
                    hint: "Removes this linked worktree checkout"
                )
        )
    }

    @Test("tmux rows include their leading icon in the primary hit region")
    func tmuxPrimaryPresentation() {
        #expect(
            AgentDashboardView.tmuxPrimaryActionPresentation(
                for: tmuxSession,
                openHere: false
            ) == .init(
                accessibility: .init(
                    label: "Attach tmux session api, 2 windows · attached",
                    hint: "Press Return or Space to attach this tmux session"
                ),
                leadingIconSystemName: "square.split.2x1",
                includesLeadingIconInPrimaryHitRegion: true,
                minimumHeight: AgentDashboardView.rowMinimumHeight
            )
        )
        #expect(
            AgentDashboardView.tmuxPrimaryActionPresentation(
                for: tmuxSession,
                openHere: true
            ).accessibility.label
                == "Attach tmux session api, 2 windows · attached, open in this window"
        )
    }

    @Test("tmux kill explains its destructive effect")
    func tmuxKillAccessibilityCopy() {
        #expect(
            AgentDashboardView.tmuxKillActionAccessibility(for: tmuxSession)
                == .init(
                    label: "Kill tmux session api",
                    hint: "Permanently ends this tmux session"
                )
        )
    }

    @Test("shared dashboard row chrome emphasizes hover and focus")
    func sharedRowChromePresentation() {
        let passive = AgentDashboardRowChrome.presentation(
            isHovered: false,
            isFocused: false
        )
        let hovered = AgentDashboardRowChrome.presentation(
            isHovered: true,
            isFocused: false
        )
        let focused = AgentDashboardRowChrome.presentation(
            isHovered: false,
            isFocused: true
        )

        #expect(passive == .init(
            isEmphasized: false,
            showsFocusStroke: false,
            minimumHeight: AgentDashboardView.rowMinimumHeight
        ))
        #expect(hovered.isEmphasized)
        #expect(focused.isEmphasized)
        #expect(focused.showsFocusStroke)
        #expect(AgentDashboardRowChrome.shouldAnimate(reduceMotion: false))
        #expect(!AgentDashboardRowChrome.shouldAnimate(reduceMotion: true))
    }

    @Test("a stale dashboard callback cannot clear a newer focus request")
    func staleCallbackPreservesNewerFocus() {
        let olderRequestID = UUID()
        let newerRequestID = UUID()

        #expect(
            WorkspaceView.agentDashboardFocusRequestID(
                newerRequestID,
                afterConsuming: olderRequestID
            ) == newerRequestID
        )
        #expect(
            WorkspaceView.agentDashboardFocusRequestID(
                newerRequestID,
                afterConsuming: newerRequestID
            ) == nil
        )
    }
}
