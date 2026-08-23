import Foundation
import Testing

@testable import HerminalApp
import HerminalDB

@Suite("Notes panel autosave policy")
@MainActor
struct NotesPanelPolicyTests {
    @Test("load-failed state disables editing and offers reload")
    func explicitLoadFailureState() {
        let state = NotesPanelView.AutosaveState.loadFailed

        #expect(state.feedback == .loadFailed)
        #expect(state.feedback.recoveryAction == .reload)
        #expect(!state.isEditorEditable)
        #expect(!state.shouldAnnounceFailure)
    }

    @Test("a successful reload rebuilds neutral state from loaded content")
    func reloadSuccessUsesLoadedContent() {
        let state = NotesPanelView.AutosaveState(draft: "Loaded from SQLite")

        #expect(state.draft == "Loaded from SQLite")
        #expect(state.feedback == .neutral)
        #expect(state.isEditorEditable)
    }

    @Test("save failure announces once per failed stretch and resets after success")
    func failureAnnouncementPolicy() {
        var state = NotesPanelView.AutosaveState()

        state.saveDidFail()
        #expect(state.feedback == .failed)
        #expect(state.feedback.recoveryAction == .retry)
        #expect(state.isEditorEditable)
        #expect(state.shouldAnnounceFailure)

        state.markFailureAnnouncementDelivered()
        #expect(!state.shouldAnnounceFailure)

        state.saveDidFail()
        #expect(state.feedback == .failed)
        #expect(!state.shouldAnnounceFailure)

        state.saveDidSucceed()
        #expect(state.feedback == .saved)
        #expect(!state.shouldAnnounceFailure)

        state.saveDidFail()
        #expect(state.feedback == .failed)
        #expect(state.shouldAnnounceFailure)
    }

    @Test("initial autosave state is neutral")
    func initialAutosaveState() {
        let state = NotesPanelView.AutosaveState()

        #expect(state.feedback == .neutral)
        #expect(state.feedback.recoveryAction == nil)
        #expect(state.isEditorEditable)
    }

    @Test("successful save reports saved feedback")
    func saveSuccessFeedback() {
        var state = NotesPanelView.AutosaveState(draft: "Saved draft")

        let effect = state.attemptSave { body in body == "Saved draft" }

        #expect(effect == .none)
        #expect(state.feedback == .saved)
        #expect(state.feedback.recoveryAction == nil)
        #expect(state.draft == "Saved draft")
    }

    @Test("failed save preserves the draft and offers retry")
    func saveFailurePreservesDraft() {
        var state = NotesPanelView.AutosaveState(draft: "Keep this edited note body")

        let effect = state.attemptSave { _ in false }

        #expect(effect == .announceFailure)
        #expect(state.feedback == .failed)
        #expect(state.feedback.recoveryAction == .retry)
        #expect(state.draft == "Keep this edited note body")
    }

    @Test("successful retry clears a prior failure")
    func retrySuccessClearsFailure() {
        var shouldSucceed = false
        var state = NotesPanelView.AutosaveState(draft: "Retry me")

        _ = state.attemptSave { _ in shouldSucceed }
        shouldSucceed = true
        let effect = state.attemptSave { body in
            shouldSucceed && body == "Retry me"
        }

        #expect(effect == .none)
        #expect(state.feedback == .saved)
        #expect(state.feedback.recoveryAction == nil)
        #expect(state.draft == "Retry me")
    }

    @Test("failed recovery keeps the unsaved draft across a host rebuild")
    func failedRecoveryRetainsUnsavedDraftAcrossHostRebuild() throws {
        var failedState = NotesPanelView.AutosaveState(draft: "Unsaved newer draft")
        failedState.saveDidFail()

        let loadedNote = Note(
            id: UUID(),
            sessionID: UUID(),
            body: "Older persisted body",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let recovery = try #require(NotesPanelRecovery.retainingFailure(failedState))
        let preferred = WorkspaceView.preferredNotesPanelState(
            loadedNote: loadedNote,
            recovery: recovery
        )

        #expect(preferred.draft == "Unsaved newer draft")
        #expect(preferred.feedback == .failed)
        #expect(preferred.feedback.recoveryAction == .retry)
        #expect(preferred.isEditorEditable)
    }

    @Test("successful save clears retained recovery and rebuilds from loaded note")
    func successfulSaveClearsRetainedRecovery() {
        var state = NotesPanelView.AutosaveState(draft: "Saved draft that should not linger")
        state.saveDidFail()
        state.saveDidSucceed()

        #expect(NotesPanelRecovery.retainingFailure(state) == nil)

        let loadedNote = Note(
            id: UUID(),
            sessionID: UUID(),
            body: "Reloaded persisted body",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 300)
        )

        let preferred = WorkspaceView.preferredNotesPanelState(
            loadedNote: loadedNote,
            recovery: NotesPanelRecovery.retainingFailure(state)
        )

        #expect(preferred.draft == "Reloaded persisted body")
        #expect(preferred.feedback == .neutral)
        #expect(preferred.feedback.recoveryAction == nil)
        #expect(preferred.isEditorEditable)
    }

    @Test("fallback writes report session-scoped success and remain recoverable")
    func fallbackStorageReportsTransientSuccess() {
        var state = NotesPanelView.AutosaveState(draft: "Keep this note")
        let effect = state.attemptSave { _ in true }

        #expect(effect == .none)
        #expect(state.feedback == .saved)
        #expect(NotesStoragePolicy.canReportSaveSuccess(writeSucceeded: true))
        #expect(!NotesStoragePolicy.canReportSaveSuccess(writeSucceeded: false))
        #expect(NotesStoragePolicy.shouldRetainClosedSurface(
            recovery: NotesPanelRecovery.retainingAtRisk(
                state,
                storageIsDurable: false
            )
        ))
    }

    @Test("transient storage copy never promises disk persistence")
    func transientStorageCopyIsTruthful() {
        #expect(
            NotesStoragePolicy.feedbackMessage(
                for: .saved,
                storageIsDurable: false
            ) == "Saved for this app session"
        )
        #expect(
            NotesStoragePolicy.emptyEditorPrompt(storageIsDurable: false)
                == "Markdown note kept until Herminal quits."
        )
        #expect(
            NotesStoragePolicy.editorAccessibilityHint(storageIsDurable: false)
                .localizedCaseInsensitiveContains("export")
        )
        #expect(
            !NotesStoragePolicy.feedbackMessage(
                for: .neutral,
                storageIsDurable: false
            ).localizedCaseInsensitiveContains("sqlite")
        )
        #expect(
            NotesStoragePolicy.editorAccessibilityHint(
                for: .failed,
                storageIsDurable: false
            ).localizedCaseInsensitiveContains("save failed")
        )
        #expect(
            NotesStoragePolicy.editorAccessibilityHint(
                for: .failed,
                storageIsDurable: false
            ).localizedCaseInsensitiveContains("retry or export")
        )
    }

    @Test("a closed surface is retained only for a non-empty failed draft")
    func closedSurfaceRecoveryPolicy() {
        var failedDraft = NotesPanelView.AutosaveState(draft: "  Keep this note  ")
        failedDraft.saveDidFail()
        var failedEmptyDraft = NotesPanelView.AutosaveState(draft: "  \n ")
        failedEmptyDraft.saveDidFail()

        #expect(NotesStoragePolicy.shouldRetainClosedSurface(
            recovery: NotesPanelRecovery.retainingAtRisk(
                failedDraft,
                storageIsDurable: true
            )
        ))
        #expect(!NotesStoragePolicy.shouldRetainClosedSurface(
            recovery: NotesPanelRecovery.retainingAtRisk(
                failedEmptyDraft,
                storageIsDurable: true
            )
        ))
        #expect(!NotesStoragePolicy.shouldRetainClosedSurface(recovery: nil))
    }

    @Test("closed-surface recovery announcement explains that the draft is still available")
    func closedSurfaceRecoveryAnnouncement() {
        #expect(
            NotesStoragePolicy.closedSurfaceRetentionAnnouncement
                == "Terminal exited. The unsaved note draft is still available for retry or export."
        )
    }
}
