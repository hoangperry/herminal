import Foundation
import Testing

@testable import HerminalApp

@Suite("Close risk policy")
struct CloseRiskPolicyTests {
    private func session(
        id: UUID = UUID(),
        hasNote: Bool = false,
        spawnedCommand: String? = nil,
        hasMappedAgent: Bool = false,
        hasLiveProcess: Bool = false
    ) -> CloseRiskSession {
        CloseRiskSession(
            id: id,
            hasNote: hasNote,
            spawnedCommand: spawnedCommand,
            hasMappedAgent: hasMappedAgent,
            hasLiveProcess: hasLiveProcess
        )
    }

    private func fingerprint(
        _ sessions: [CloseRiskSession],
        includeNotes: Bool = true
    ) -> CloseRiskFingerprint {
        CloseRiskFingerprint(sessions: Set(sessions), includeNotes: includeNotes)
    }

    @Test("empty and safe shell sessions stay closable without confirmation")
    func safeShellDoesNotRequireConfirmation() {
        let assessment = CloseRiskAssessment.assess(
            [
                session(spawnedCommand: nil),
                session(spawnedCommand: "   ")
            ],
            includeNotes: true
        )

        #expect(assessment.notedSessionCount == 0)
        #expect(assessment.liveProcessSessionCount == 0)
        #expect(assessment.activeAgentSessionCount == 0)
        #expect(assessment.longLivedCommandSessionCount == 0)
        #expect(!assessment.requiresConfirmation)
    }

    @Test("a live process requires confirmation even in a plain shell")
    func livePlainShellRequiresConfirmation() {
        let assessment = CloseRiskAssessment.assess(
            [session(hasLiveProcess: true)],
            includeNotes: false
        )

        #expect(assessment.notedSessionCount == 0)
        #expect(assessment.liveProcessSessionCount == 1)
        #expect(assessment.activeAgentSessionCount == 0)
        #expect(assessment.longLivedCommandSessionCount == 0)
        #expect(assessment.requiresConfirmation)
        #expect(
            assessment.informativeText.localizedCaseInsensitiveContains(
                "running process"
            )
        )
    }

    @Test("a live-process signal dominates heuristic risk labels")
    func liveProcessDoesNotDoubleCountHeuristics() {
        let assessment = CloseRiskAssessment.assess(
            [
                session(
                    spawnedCommand: "ssh ops@example.com",
                    hasMappedAgent: true,
                    hasLiveProcess: true
                )
            ],
            includeNotes: false
        )

        #expect(assessment.liveProcessSessionCount == 1)
        #expect(assessment.activeAgentSessionCount == 0)
        #expect(assessment.longLivedCommandSessionCount == 0)
    }

    @Test("notes only count when note warnings are included")
    func notesRespectIncludeFlag() {
        let sessions = [session(hasNote: true)]

        let excluded = CloseRiskAssessment.assess(
            sessions,
            includeNotes: false
        )
        #expect(excluded.notedSessionCount == 0)
        #expect(!excluded.requiresConfirmation)

        let included = CloseRiskAssessment.assess(
            sessions,
            includeNotes: true
        )
        #expect(included.notedSessionCount == 1)
        #expect(included.activeAgentSessionCount == 0)
        #expect(included.longLivedCommandSessionCount == 0)
        #expect(included.requiresConfirmation)
        #expect(included.informativeText.localizedCaseInsensitiveContains("may become unavailable"))
        #expect(
            included.informativeText.localizedCaseInsensitiveContains(
                "copy or export"
            )
        )
        #expect(!included.informativeText.localizedCaseInsensitiveContains("stay on disk"))
        #expect(!included.informativeText.localizedCaseInsensitiveContains("workspace ui"))
    }

    @Test("plural close-risk copy agrees with multi-session counts")
    func pluralRiskCopyUsesPluralGrammar() {
        let assessment = CloseRiskAssessment.assess(
            [
                session(hasNote: true),
                session(hasNote: true),
                session(hasMappedAgent: true),
                session(hasMappedAgent: true),
                session(spawnedCommand: "ssh ops@example.com"),
                session(spawnedCommand: "tmux attach -t ops")
            ],
            includeNotes: true
        )

        #expect(
            assessment.informativeText.localizedCaseInsensitiveContains(
                "2 sessions have notes"
            )
        )
        #expect(
            assessment.informativeText.localizedCaseInsensitiveContains(
                "2 sessions appear to contain ai agents"
            )
        )
        #expect(
            assessment.informativeText.localizedCaseInsensitiveContains(
                "2 sessions appear to contain ssh, tmux, or agent commands"
            )
        )
    }

    @Test("mapped agents require confirmation without double counting their launch command")
    func mappedAgentDominatesLongLivedCommandCount() {
        let assessment = CloseRiskAssessment.assess(
            [
                session(
                    spawnedCommand: "  /usr/local/bin/codex chat  ",
                    hasMappedAgent: true
                )
            ],
            includeNotes: false
        )

        #expect(assessment.notedSessionCount == 0)
        #expect(assessment.activeAgentSessionCount == 1)
        #expect(assessment.longLivedCommandSessionCount == 0)
        #expect(assessment.requiresConfirmation)
        #expect(assessment.informativeText.localizedCaseInsensitiveContains("appears"))
        #expect(
            assessment.informativeText.localizedCaseInsensitiveContains(
                "may still be active"
            )
        )
    }

    @Test("recognized long-lived launch commands require confirmation")
    func longLivedCommandsRequireConfirmation() {
        let commands = [
            "ssh ops@example.com",
            "  /usr/bin/ssh ops@example.com  ",
            "tmux attach-session -t api",
            " /opt/homebrew/bin/tmux new-session -A -s api ",
            "claude --resume",
            "  /Users/test/bin/claude  ",
            "codex exec",
            " /usr/local/bin/codex ",
            "aider --model sonnet",
            " /bin/aider --message hi "
        ]

        for command in commands {
            let assessment = CloseRiskAssessment.assess(
                [session(spawnedCommand: command)],
                includeNotes: false
            )

            #expect(assessment.notedSessionCount == 0)
            #expect(assessment.activeAgentSessionCount == 0)
            #expect(assessment.longLivedCommandSessionCount == 1)
            #expect(assessment.requiresConfirmation)
            #expect(assessment.informativeText.localizedCaseInsensitiveContains("appears"))
            #expect(
                assessment.informativeText.localizedCaseInsensitiveContains(
                    "may still be active"
                )
            )
        }
    }

    @Test("unrelated commands like lazygit and zsh do not trigger close risk")
    func unrelatedCommandsDoNotTriggerCloseRisk() {
        let commands = [
            "lazygit",
            " /opt/homebrew/bin/lazygit ",
            "zsh",
            " /bin/zsh -l "
        ]

        for command in commands {
            let assessment = CloseRiskAssessment.assess(
                [session(spawnedCommand: command)],
                includeNotes: false
            )

            #expect(assessment.notedSessionCount == 0)
            #expect(assessment.activeAgentSessionCount == 0)
            #expect(assessment.longLivedCommandSessionCount == 0)
            #expect(!assessment.requiresConfirmation)
        }
    }

    @Test("window approval suppresses only the immediate matching termination prompt")
    func windowApprovalIsOneShot() {
        var gate = CloseRiskGate()
        let approvedRisk = fingerprint([session(hasNote: true)])

        gate.recordWindowClose(approvedFingerprint: approvedRisk)
        let firstConsumption = gate.consumeWindowCloseApproval(
            matchingCurrentFingerprint: approvedRisk
        )
        let secondConsumption = gate.consumeWindowCloseApproval(
            matchingCurrentFingerprint: approvedRisk
        )
        #expect(firstConsumption)
        #expect(!secondConsumption)

        gate.recordWindowClose(approvedFingerprint: nil)
        let cancelledConsumption = gate.consumeWindowCloseApproval(
            matchingCurrentFingerprint: approvedRisk
        )
        #expect(!cancelledConsumption)

        gate.recordWindowClose(approvedFingerprint: approvedRisk)
        gate.clearWindowCloseApproval()
        let clearedConsumption = gate.consumeWindowCloseApproval(
            matchingCurrentFingerprint: approvedRisk
        )
        #expect(!clearedConsumption)
    }

    @Test("approved workspace close survives an auxiliary window while live sessions stay unchanged")
    func workspaceApprovalSurvivesAuxiliaryWindow() {
        var gate = CloseRiskGate()
        let approvedRisk = fingerprint([
            session(hasNote: true),
            session(spawnedCommand: "ssh ops@example.com")
        ])

        gate.recordWindowClose(approvedFingerprint: approvedRisk)

        let approvalAfterAuxiliaryWindowCloses = gate.consumeWindowCloseApproval(
            matchingCurrentFingerprint: approvedRisk
        )
        let laterExplicitQuit = gate.consumeWindowCloseApproval(
            matchingCurrentFingerprint: approvedRisk
        )
        #expect(approvalAfterAuxiliaryWindowCloses)
        #expect(!laterExplicitQuit)
    }

    @Test("window-close approval is invalidated when risk changes without changing session identity")
    func workspaceApprovalDoesNotBypassChangedRisk() {
        var gate = CloseRiskGate()
        let id = UUID()
        let approvedRisk = fingerprint([session(id: id, hasNote: true)])
        let changedRisk = fingerprint([
            session(id: id, hasNote: true, spawnedCommand: "ssh ops@example.com")
        ])

        gate.recordWindowClose(approvedFingerprint: approvedRisk)

        let consumed = gate.consumeWindowCloseApproval(
            matchingCurrentFingerprint: changedRisk
        )

        #expect(!consumed)
    }

    @Test("last visible workspace window is presented as quitting the app")
    func windowCloseActionReflectsTermination() {
        #expect(CloseRiskAction.windowClose(isLastVisibleWindow: false) == .closeWorkspace)
        #expect(CloseRiskAction.windowClose(isLastVisibleWindow: true) == .quitApplication)
    }

    @Test("closing the workspace explains the eventual app termination")
    func workspaceClosePresentationExplainsFollowUpQuit() {
        let assessment = CloseRiskAssessment.assess(
            [session(hasNote: true)],
            includeNotes: true
        )

        let presentation = CloseRiskAlertPresentation(
            action: .closeWorkspace,
            assessment: assessment
        )

        #expect(presentation.messageText == "Close Workspace with active work?")
        #expect(presentation.destructiveButtonTitle == "Close Workspace")
        #expect(
            presentation.informativeText.localizedCaseInsensitiveContains(
                "quit after its remaining windows close"
            )
        )
    }

    @Test("close-risk alerts default to cancel and mark the requested action destructive")
    func alertPresentationIsFailClosed() {
        let assessment = CloseRiskAssessment.assess(
            [session(spawnedCommand: "ssh ops@example.com")],
            includeNotes: false
        )

        let presentation = CloseRiskAlertPresentation(
            action: .quitApplication,
            assessment: assessment
        )

        #expect(presentation.messageText == "Quit Herminal with active work?")
        #expect(presentation.defaultButtonTitle == "Cancel")
        #expect(presentation.destructiveButtonTitle == "Quit Herminal")
        #expect(presentation.informativeText == assessment.informativeText)
    }

    @Test("close-note preference copy keeps note warnings scoped and live-work warnings explicit")
    func closeNotePreferencePresentation() {
        let presentation = Preferences.closeNoteWarningPresentation

        #expect(presentation.title == "Warn when closing sessions with notes")
        #expect(
            presentation.help.localizedCaseInsensitiveContains(
                "remain on to protect"
            )
        )
        #expect(
            presentation.help.localizedCaseInsensitiveContains(
                "ssh, tmux, and agent sessions"
            )
        )
    }
}
