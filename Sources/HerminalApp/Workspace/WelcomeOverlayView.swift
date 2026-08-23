// WelcomeOverlayView — the one-time first-run hint card.
//
// Shows ONCE, on the first launch where `Preferences.firstRunCompleted`
// is still false. Dismissing the card calls `markFirstRunCompleted()`,
// so subsequent launches never see it again.
//
// Why a SwiftUI overlay (not an alert / modal sheet): NSAlert blocks
// the run loop, and a sheet would block the terminal surface — both
// would hide the shell prompt the user just landed on. The translucent
// backdrop lets the terminal stay visible behind the card, so the
// first-launch screen still feels like an actual terminal, not a
// product-tour walkthrough.

import SwiftUI

struct WelcomeOverlayView: View {
    enum DismissalSource: Equatable {
        case primaryAction
        case escape
        case backdrop
    }

    enum FocusTarget: Hashable {
        case primaryAction
    }

    struct AccessibilityPresentation: Equatable {
        let heading: String
        let isModal: Bool
    }

    static let initialFocusTarget: FocusTarget = .primaryAction
    static let accessibilityPresentation = AccessibilityPresentation(
        heading: "Welcome to herminal",
        isModal: true
    )

    let onDismiss: () -> Void
    @FocusState private var focusedTarget: FocusTarget?

    var body: some View {
        ZStack {
            // Backdrop — dim so the card pops, but not so dark that the
            // terminal prompt behind it disappears. It intentionally has
            // no dismiss gesture: an accidental click must not permanently
            // consume one-shot onboarding.
            HerminalDesign.Palette.surfaceBase
                .opacity(0.78)
                .ignoresSafeArea()

            card
                .frame(maxWidth: 460)
                .padding(.horizontal, 24)
        }
        .onExitCommand { requestDismissal(from: .escape) }
        .onAppear { focusedTarget = Self.initialFocusTarget }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Self.accessibilityPresentation.heading)
                    .font(HerminalDesign.Typography.largeTitle)
                    .foregroundColor(HerminalDesign.Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Press ⌘⇧P any time to search every command. A few to start:")
                    .font(HerminalDesign.Typography.body)
                    .foregroundColor(HerminalDesign.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                shortcut("⌘⇧P", "Command palette — every action, searchable")
                shortcut("⌘T", "New tab")
                shortcut("⌘D", "Split pane (⌘⇧Return zooms it)")
                shortcut("⌘⇧C", "Resume a Claude Code session")
                shortcut("⌘⌥A", "New agent pane — Claude in a split")
                shortcut("⌘⌥W", "New agent worktree — isolated branch")
                shortcut("⌘⇧A", "Toggle agent dashboard")
                shortcut("⌘⇧N", "Toggle per-session notes")
                shortcut("⌘,", "Open Settings")
            }
            .padding(.vertical, 4)

            HStack {
                Spacer()
                Button(action: { requestDismissal(from: .primaryAction) }) {
                    Text("Got it")
                        .font(HerminalDesign.Typography.bodyEmphasis)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(HerminalDesign.Palette.accent)
                .focused($focusedTarget, equals: .primaryAction)
                .accessibilityHint("Dismiss the welcome guide and continue to the terminal")
            }
        }
        .padding(24)
        .background(HerminalDesign.Palette.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(HerminalDesign.Palette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.35), radius: 24, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func shortcut(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(HerminalDesign.Palette.textPrimary)
                .frame(minWidth: 56, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HerminalDesign.Palette.surfaceOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(label)
                .font(HerminalDesign.Typography.body)
                .foregroundColor(HerminalDesign.Palette.textSecondary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.shortcutAccessibilityLabel(keys: keys, action: label))
    }

    static func shouldDismiss(from source: DismissalSource) -> Bool {
        source != .backdrop
    }

    static func shortcutAccessibilityLabel(keys: String, action: String) -> String {
        "\(action). Shortcut \(keys)"
    }

    /// Internal so the AppKit integration test can drive the same Escape /
    /// primary-action path as SwiftUI without synthesizing a fragile key event.
    func requestDismissal(from source: DismissalSource) {
        guard Self.shouldDismiss(from: source) else { return }
        onDismiss()
    }
}
