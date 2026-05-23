// NotesPanelView — per-session notes editor. SwiftUI chrome, design tokens.
// The host rebuilds this view (with a fresh .id) when the active session
// changes, so @State text re-initialises from the new session's note.

import SwiftUI

struct NotesPanelView: View {
    let sessionTitle: String
    let onSave: (String) -> Void

    @State private var text: String

    init(sessionTitle: String, initialText: String, onSave: @escaping (String) -> Void) {
        self.sessionTitle = sessionTitle
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HerminalDesign.Palette.divider)
            TextEditor(text: $text)
                .font(HerminalDesign.Typography.mono)
                .foregroundStyle(HerminalDesign.Palette.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(HerminalDesign.Spacing.sm)
                .onChange(of: text) { _, newValue in onSave(newValue) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HerminalDesign.Palette.surfaceElevated)
    }

    private var header: some View {
        HStack {
            Text("NOTES")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
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
