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
    @Published var needle: String = "" {
        willSet {
            guard newValue != needle else { return }
            total = nil
            selected = nil
        }
    }
    /// Match count reported by libghostty (`GHOSTTY_ACTION_SEARCH_TOTAL`).
    /// nil until libghostty has scanned the buffer.
    @Published var total: Int? = nil
    /// 0-based index of the current match
    /// (`GHOSTTY_ACTION_SEARCH_SELECTED`). nil before navigation starts.
    @Published var selected: Int? = nil
    /// Monotonic signal used when an already-visible overlay needs to return
    /// keyboard focus to its SwiftUI text field.
    @Published private(set) var focusRequestRevision: UInt = 0

    func requestFieldFocus() {
        focusRequestRevision &+= 1
    }
}

struct SearchOverlayView: View {
    struct AccessibilityPresentation: Equatable {
        let label: String
        let hint: String
    }

    struct MatchCountPresentation: Equatable {
        let visibleText: String?
        let accessibilityLabel: String?
    }

    enum EscapeDismissalScope: Equatable {
        case focusedField
        case overlay
    }

    static let compactControlSize = HerminalDesign.Geometry.compactInteractiveControlSize
    static let escapeDismissalScope: EscapeDismissalScope = .overlay
    static let searchFieldAccessibilityPresentation = AccessibilityPresentation(
        label: "Search scrollback",
        hint: "Type to search the current terminal scrollback"
    )
    static let previousMatchAccessibilityPresentation = AccessibilityPresentation(
        label: "Previous match",
        hint: "Press Command-Shift-G to move to the previous match"
    )
    static let nextMatchAccessibilityPresentation = AccessibilityPresentation(
        label: "Next match",
        hint: "Press Command-G or Return to move to the next match"
    )
    static let closeAccessibilityPresentation = AccessibilityPresentation(
        label: "Close search",
        hint: "Press Escape to dismiss the search overlay"
    )
    @ObservedObject var state: SearchOverlayState
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onDismiss: () -> Void

    @FocusState private var fieldFocused: Bool

    var body: some View {
        let matchCount = Self.matchCountPresentation(
            needle: state.needle,
            selected: state.selected,
            total: state.total
        )
        let matchNavigationIsEnabled = Self.matchNavigationIsEnabled(
            needle: state.needle,
            total: state.total
        )
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(HerminalDesign.Palette.textSecondary)
                .accessibilityHidden(true)
            TextField("Search scrollback", text: $state.needle)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(HerminalDesign.Palette.textPrimary)
                .focused($fieldFocused)
                .frame(minWidth: 200)
                .accessibilityLabel(Self.searchFieldAccessibilityPresentation.label)
                .accessibilityHint(Self.searchFieldAccessibilityPresentation.hint)
                .onSubmit(onNext)
            // Match count chip — "12 / 47" when both known, "…" while
            // libghostty is still scanning. Hidden when needle is empty
            // so the bar reads as a quiet starting state.
            if let visibleText = matchCount.visibleText {
                Text(visibleText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(HerminalDesign.Palette.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HerminalDesign.Palette.surfaceOverlay)
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(matchCount.accessibilityLabel ?? visibleText)
            }
            SearchOverlayIconButton(
                systemName: "chevron.up",
                help: "Previous (⌘⇧G)",
                accessibility: Self.previousMatchAccessibilityPresentation,
                action: onPrevious
            )
            .disabled(!matchNavigationIsEnabled)
            SearchOverlayIconButton(
                systemName: "chevron.down",
                help: "Next (⌘G / Enter)",
                accessibility: Self.nextMatchAccessibilityPresentation,
                action: onNext
            )
            .disabled(!matchNavigationIsEnabled)
            SearchOverlayIconButton(
                systemName: "xmark",
                help: "Close (Esc)",
                accessibility: Self.closeAccessibilityPresentation,
                action: onDismiss
            )
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
        .onExitCommand(perform: onDismiss)
        .onAppear {
            Self.requestInitialFocus {
                fieldFocused = true
            }
        }
        .onChange(of: state.focusRequestRevision) { _, _ in
            Self.requestInitialFocus {
                fieldFocused = true
            }
        }
    }

    static func requestInitialFocus(
        _ focus: @escaping @MainActor @Sendable () -> Void
    ) {
        DispatchQueue.main.async {
            focus()
        }
    }

    static func matchCountPresentation(
        needle: String,
        selected: Int?,
        total: Int?
    ) -> MatchCountPresentation {
        guard !needle.isEmpty else {
            return .init(visibleText: nil, accessibilityLabel: nil)
        }
        guard let total, total >= 0 else {
            return .init(visibleText: "…", accessibilityLabel: "Search in progress")
        }
        guard total > 0 else {
            return .init(visibleText: "no matches", accessibilityLabel: "No matches")
        }
        if let selected, (0..<total).contains(selected) {
            return .init(
                visibleText: "\(selected + 1) / \(total)",
                accessibilityLabel: "Match \(selected + 1) of \(total)"
            )
        }
        let totalLabel = total == 1 ? "1 match" : "\(total) matches"
        return .init(visibleText: totalLabel, accessibilityLabel: totalLabel)
    }

    static func matchNavigationIsEnabled(needle: String, total: Int?) -> Bool {
        guard !needle.isEmpty, let total else { return false }
        return total > 0
    }

}

private struct SearchOverlayIconButton: View {
    let systemName: String
    let help: String
    let accessibility: SearchOverlayView.AccessibilityPresentation
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    private var isEmphasized: Bool { isEnabled && (isHovered || isFocused) }

    private var foregroundColor: Color {
        guard isEnabled else {
            return HerminalDesign.Palette.textTertiary.opacity(0.6)
        }
        return isEmphasized
            ? HerminalDesign.Palette.accent
            : HerminalDesign.Palette.textSecondary
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(foregroundColor)
                .frame(
                    width: SearchOverlayView.compactControlSize,
                    height: SearchOverlayView.compactControlSize
                )
                .background(
                    RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                        .fill(isEmphasized ? HerminalDesign.Palette.surfaceOverlay : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                        .strokeBorder(
                            isFocused ? HerminalDesign.Palette.accent.opacity(0.55) : .clear,
                            lineWidth: 1
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(accessibility.label)
        .accessibilityHint(accessibility.hint)
    }
}
