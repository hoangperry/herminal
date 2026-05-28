// SearchOverlayView — the ⌘F find bar that floats over a terminal pane.
//
// libghostty owns the match machinery: we send it `search:<needle>`
// binding actions to update what's being searched, `navigate_search:next`
// / `previous` to walk matches, and `end_search` to dismiss. libghostty
// fires SEARCH_TOTAL + SEARCH_SELECTED actions back which the workspace
// translates into bindings on this view.
//
// All the heavy lifting (scanning the scrollback, highlighting matches
// in the Metal render) happens inside libghostty — this view is just
// the AppKit-side text field + match count chip.

import SwiftUI

@MainActor
final class SearchOverlayState: ObservableObject {
    /// Current needle. SwiftUI two-way binds the TextField to this; the
    /// owning WorkspaceView observes via Combine and fires
    /// `search:<needle>` whenever it changes.
    @Published var needle: String = ""
    /// Match count reported by libghostty (`GHOSTTY_ACTION_SEARCH_TOTAL`).
    /// nil until libghostty has scanned the buffer.
    @Published var total: Int? = nil
    /// 0-based index of the current match
    /// (`GHOSTTY_ACTION_SEARCH_SELECTED`). nil before navigation starts.
    @Published var selected: Int? = nil
}

struct SearchOverlayView: View {
    @ObservedObject var state: SearchOverlayState
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onDismiss: () -> Void

    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(HerminalDesign.Palette.textSecondary)
            TextField("Search scrollback", text: $state.needle)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(HerminalDesign.Palette.textPrimary)
                .focused($fieldFocused)
                .frame(minWidth: 200)
                .onSubmit(onNext)
                .onKeyPress(.escape) {
                    onDismiss()
                    return .handled
                }
            // Match count chip — "12 / 47" when both known, "?" while
            // libghostty is still scanning. Hidden when needle is empty
            // so the bar reads as a quiet starting state.
            if !state.needle.isEmpty {
                Text(matchCountLabel)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(HerminalDesign.Palette.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HerminalDesign.Palette.surfaceOverlay)
                    )
            }
            iconButton("chevron.up", help: "Previous (⌘⇧G)", action: onPrevious)
            iconButton("chevron.down", help: "Next (⌘G / Enter)", action: onNext)
            iconButton("xmark", help: "Close (Esc)", action: onDismiss)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(HerminalDesign.Palette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(HerminalDesign.Palette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.35), radius: 14, y: 6)
        .onAppear {
            // Defer the focus grab so the overlay finishes its slide-in
            // before the field starts intercepting keystrokes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                fieldFocused = true
            }
        }
    }

    private var matchCountLabel: String {
        switch (state.selected, state.total) {
        case let (.some(sel), .some(tot)) where tot > 0:
            return "\(sel + 1) / \(tot)"
        case (.none, .some(let tot)) where tot > 0:
            return "\(tot) matches"
        case (_, .some(0)):
            return "no matches"
        default:
            return "…"
        }
    }

    private func iconButton(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(HerminalDesign.Palette.textSecondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
