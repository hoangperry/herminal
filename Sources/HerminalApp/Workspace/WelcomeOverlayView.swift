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
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Backdrop — dim so the card pops, but not so dark that the
            // terminal prompt behind it disappears. Click anywhere on the
            // backdrop also dismisses.
            HerminalDesign.Palette.surfaceBase
                .opacity(0.78)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            card
                .frame(maxWidth: 460)
                .padding(.horizontal, 24)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to herminal")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(HerminalDesign.Palette.textPrimary)
                Text("A few shortcuts to get you started.")
                    .font(.system(size: 13))
                    .foregroundColor(HerminalDesign.Palette.textSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                shortcut("⌘T", "New tab")
                shortcut("⌘D", "Split pane right")
                shortcut("⌘⇧D", "Split pane down")
                shortcut("⌘⇧A", "Toggle agent dashboard")
                shortcut("⌘⇧S", "Toggle SSH hosts")
                shortcut("⌘⇧N", "Toggle notes")
                shortcut("⌘,", "Open Settings")
            }
            .padding(.vertical, 4)

            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Text("Got it")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(HerminalDesign.Palette.accent)
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
                .font(.system(size: 13))
                .foregroundColor(HerminalDesign.Palette.textSecondary)
            Spacer(minLength: 0)
        }
    }
}
