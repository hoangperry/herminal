// NotesPanelView — per-session notes editor. SwiftUI chrome, design tokens.
// The host rebuilds this view (with a fresh .id) when the active session
// changes, so @State text re-initialises from the new session's note.

import SwiftUI

enum NotesStoragePolicy {
    static let closedSurfaceRetentionAnnouncement =
        "Terminal exited. The unsaved note draft is still available for retry or export."

    static func canReportSaveSuccess(writeSucceeded: Bool) -> Bool {
        writeSucceeded
    }

    static func feedbackMessage(
        for feedback: NotesPanelView.AutosaveFeedback,
        storageIsDurable: Bool
    ) -> String {
        switch feedback {
        case .neutral:
            return storageIsDurable
                ? "Local SQLite · session-scoped"
                : "Memory only · export before quitting"
        case .saved:
            return storageIsDurable ? "Saved locally" : "Saved for this app session"
        case .failed:
            return "Save failed"
        case .loadFailed:
            return "Couldn’t load this session note"
        }
    }

    static func emptyEditorPrompt(storageIsDurable: Bool) -> String {
        storageIsDurable
            ? "Notes for this session. Markdown, saved as you type."
            : "Markdown note kept until Herminal quits."
    }

    static func editorAccessibilityHint(storageIsDurable: Bool) -> String {
        storageIsDurable
            ? "Saved automatically as you type"
            : "Kept only for this app session. Export important notes before quitting."
    }

    static func editorAccessibilityHint(
        for feedback: NotesPanelView.AutosaveFeedback,
        storageIsDurable: Bool
    ) -> String {
        if feedback == .failed {
            return "The last save failed. Retry or export the current note before closing."
        }
        return editorAccessibilityHint(storageIsDurable: storageIsDurable)
    }

    static func shouldRetainClosedSurface(recovery: NotesPanelRecovery?) -> Bool {
        guard let draft = recovery?.state.draft else { return false }
        return !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Note state kept outside SwiftUI when a failed write or transient storage
/// could otherwise make the current draft unavailable during a host rebuild.
struct NotesPanelRecovery: Equatable {
    let state: NotesPanelView.AutosaveState
    let noteID: UUID?
    let createdAt: Date?

    static func retainingFailure(
        _ state: NotesPanelView.AutosaveState,
        noteID: UUID? = nil,
        createdAt: Date? = nil
    ) -> NotesPanelRecovery? {
        retainingAtRisk(
            state,
            storageIsDurable: true,
            noteID: noteID,
            createdAt: createdAt
        )
    }

    static func retainingAtRisk(
        _ state: NotesPanelView.AutosaveState,
        storageIsDurable: Bool,
        noteID: UUID? = nil,
        createdAt: Date? = nil
    ) -> NotesPanelRecovery? {
        guard !state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              state.feedback == .failed || !storageIsDurable else { return nil }
        return NotesPanelRecovery(state: state, noteID: noteID, createdAt: createdAt)
    }
}

struct NotesPanelView: View {
    enum SaveEffect: Equatable {
        case none
        case announceFailure
    }

    enum AutosaveFeedback: Equatable {
        enum RecoveryAction: Equatable {
            case retry
            case reload
        }

        case neutral
        case saved
        case failed
        case loadFailed

        var recoveryAction: RecoveryAction? {
            switch self {
            case .failed:
                return .retry
            case .loadFailed:
                return .reload
            default:
                return nil
            }
        }

    }

    struct AutosaveState: Equatable {
        var draft: String
        private(set) var feedback: AutosaveFeedback = .neutral
        private(set) var isEditorEditable = true
        private(set) var shouldAnnounceFailure = false

        init(draft: String = "") {
            self.draft = draft
        }

        static var loadFailed: AutosaveState {
            var state = AutosaveState()
            state.feedback = .loadFailed
            state.isEditorEditable = false
            return state
        }

        mutating func saveDidSucceed() {
            feedback = .saved
            isEditorEditable = true
            shouldAnnounceFailure = false
        }

        mutating func saveDidFail() {
            if feedback != .failed {
                shouldAnnounceFailure = true
            }
            feedback = .failed
        }

        mutating func markFailureAnnouncementDelivered() {
            shouldAnnounceFailure = false
        }

        mutating func attemptSave(using save: (String) -> Bool) -> SaveEffect {
            guard save(draft) else {
                saveDidFail()
                guard shouldAnnounceFailure else { return .none }
                markFailureAnnouncementDelivered()
                return .announceFailure
            }
            saveDidSucceed()
            return .none
        }
    }

    let sessionTitle: String
    let storageIsDurable: Bool
    let onReload: (() -> Void)?
    let onSaveFailure: () -> Void
    let onStateChange: (AutosaveState) -> Void
    let onSave: (String) -> Bool

    @State private var autosaveState: AutosaveState

    init(
        sessionTitle: String,
        initialState: AutosaveState,
        storageIsDurable: Bool = true,
        onReload: (() -> Void)? = nil,
        onSaveFailure: @escaping () -> Void = {},
        onStateChange: @escaping (AutosaveState) -> Void = { _ in },
        onSave: @escaping (String) -> Bool
    ) {
        self.sessionTitle = sessionTitle
        self.storageIsDurable = storageIsDurable
        self.onReload = onReload
        self.onSaveFailure = onSaveFailure
        self.onStateChange = onStateChange
        self.onSave = onSave
        _autosaveState = State(initialValue: initialState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HerminalDesign.Palette.divider)
            TextEditor(text: $autosaveState.draft)
                .font(HerminalDesign.Typography.mono)
                .foregroundStyle(HerminalDesign.Palette.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(HerminalDesign.Spacing.sm)
                .disabled(!autosaveState.isEditorEditable)
                .accessibilityLabel("Session note")
                .accessibilityHint(editorAccessibilityHint)
                // An untouched note was an unexplained void — the only panel
                // in the sidebar with no empty state. Sits behind the editor
                // and ignores hits so the first click still lands in the text.
                .overlay(alignment: .topLeading) {
                    if autosaveState.isEditorEditable && autosaveState.draft.isEmpty {
                        Text(
                            NotesStoragePolicy.emptyEditorPrompt(
                                storageIsDurable: storageIsDurable
                            )
                        )
                            .font(HerminalDesign.Typography.caption)
                            .foregroundStyle(HerminalDesign.Palette.textSecondary)
                            .padding(.horizontal, HerminalDesign.Spacing.md)
                            .padding(.top, HerminalDesign.Spacing.md)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .overlay {
                    if !autosaveState.isEditorEditable {
                        unavailableOverlay
                    }
                }
                .onChange(of: autosaveState.draft) { _, newValue in save(newValue) }
            Divider().overlay(HerminalDesign.Palette.divider)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HerminalDesign.Palette.surfaceElevated)
    }

    private var footer: some View {
        HStack(spacing: HerminalDesign.Spacing.xs) {
            if isFailureFeedback {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.statusError)
                    .accessibilityHidden(true)
            }
            Text(feedbackMessage)
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(footerColor)
                .accessibilityLabel(statusAccessibilityLabel)
                .accessibilityValue(feedbackMessage)
            Spacer(minLength: 0)
            if let recoveryAction = recoveryAction {
                Button(recoveryLabel(for: recoveryAction)) {
                    performRecoveryAction(recoveryAction)
                }
                .buttonStyle(.plain)
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textPrimary)
                .accessibilityHint(recoveryHint(for: recoveryAction))
                .help(recoveryHint(for: recoveryAction))
            }
        }
        .padding(.horizontal, HerminalDesign.Spacing.md)
        .frame(height: Self.footerHeight)
    }

    private var footerColor: Color {
        isFailureFeedback
            ? HerminalDesign.Palette.textPrimary
            : HerminalDesign.Palette.textSecondary
    }

    private var isFailureFeedback: Bool {
        autosaveState.feedback == .failed || autosaveState.feedback == .loadFailed
    }

    private var statusAccessibilityLabel: String {
        autosaveState.feedback == .loadFailed ? "Notes storage status" : "Notes autosave status"
    }

    private var feedbackMessage: String {
        NotesStoragePolicy.feedbackMessage(
            for: autosaveState.feedback,
            storageIsDurable: storageIsDurable
        )
    }

    private var recoveryAction: AutosaveFeedback.RecoveryAction? {
        switch autosaveState.feedback.recoveryAction {
        case .reload where onReload == nil:
            return nil
        default:
            return autosaveState.feedback.recoveryAction
        }
    }

    private func save(_ body: String) {
        guard autosaveState.isEditorEditable else { return }
        autosaveState.draft = body
        let effect = autosaveState.attemptSave(using: onSave)
        onStateChange(autosaveState)
        if effect == .announceFailure {
            onSaveFailure()
        }
    }

    private static let footerHeight: CGFloat = 28

    private var unavailableOverlay: some View {
        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xs) {
            Text("Note unavailable")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textPrimary)
            Text("Local storage could not load this note. Reload before editing so herminal doesn’t overwrite unknown content.")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HerminalDesign.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HerminalDesign.Palette.surfaceElevated.opacity(0.92))
        .allowsHitTesting(false)
    }

    private func performRecoveryAction(_ action: AutosaveFeedback.RecoveryAction) {
        switch action {
        case .retry:
            save(autosaveState.draft)
        case .reload:
            onReload?()
        }
    }

    private func recoveryLabel(for action: AutosaveFeedback.RecoveryAction) -> String {
        switch action {
        case .retry:
            return "Retry"
        case .reload:
            return "Reload"
        }
    }

    private func recoveryHint(for action: AutosaveFeedback.RecoveryAction) -> String {
        switch action {
        case .retry:
            return "Attempts to save the current note again"
        case .reload:
            return "Attempts to load the current note again"
        }
    }

    private var editorAccessibilityHint: String {
        autosaveState.isEditorEditable
            ? NotesStoragePolicy.editorAccessibilityHint(
                for: autosaveState.feedback,
                storageIsDurable: storageIsDurable
            )
            : "Unavailable until the note reload succeeds"
    }

    private var header: some View {
        HStack {
            Text("NOTES")
                .font(HerminalDesign.Typography.caption)
                .tracking(HerminalDesign.Typography.headerTracking)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text(sessionTitle)
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .lineLimit(1)
                .accessibilityLabel("Notes for session \(sessionTitle)")
        }
        .padding(.horizontal, HerminalDesign.Spacing.md)
        .frame(height: TabBarView.barHeight)
    }
}
