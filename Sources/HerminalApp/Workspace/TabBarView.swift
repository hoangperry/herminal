// TabBarView — the workspace tab strip. SwiftUI chrome styled from design tokens.
// Stateless: WorkspaceView rebuilds it whenever sessions or selection change.

import SwiftUI

struct TabBarView: View {
    static let barHeight: CGFloat = 36

    struct Tab: Identifiable {
        let id: UUID
        let title: String
    }

    let tabs: [Tab]
    let activeID: UUID?
    /// Space to keep clear at the leading edge for the window's traffic
    /// lights. The strip's *background* still spans the full width so the
    /// titlebar row reads as one continuous surface; only the chips move.
    var leadingInset: CGFloat = 0
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onNew: () -> Void

    var body: some View {
        HStack(spacing: HerminalDesign.Spacing.xxs) {
            ForEach(tabs) { tab in
                TabChip(tab: tab,
                        isActive: tab.id == activeID,
                        onSelect: { onSelect(tab.id) },
                        onClose: { onClose(tab.id) })
            }
            NewTabButton(action: onNew)
            Spacer(minLength: 0)
        }
        .padding(.leading, HerminalDesign.Spacing.sm + leadingInset)
        .padding(.trailing, HerminalDesign.Spacing.sm)
        .frame(height: Self.barHeight)
        .frame(maxWidth: .infinity)
        .background(HerminalDesign.Palette.surfaceElevated)
        .overlay(alignment: .bottom) {
            HerminalDesign.Palette.border.frame(height: 1)
        }
    }
}

/// Hover-aware tab chip. Local `@State` keeps the hover highlight on
/// just this chip — sibling tabs don't redraw on mouse-over.
private struct TabChip: View {
    let tab: TabBarView.Tab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @State private var isCloseHovered = false

    var body: some View {
        HStack(spacing: HerminalDesign.Spacing.xs) {
            // v1.0 polish: the active tab carries an accent dot and the
            // title is monospaced — matches the launch-site hero mockup.
            // The dot is always laid out and only faded, so switching
            // tabs never changes chip width or reflows the strip.
            Circle()
                .fill(HerminalDesign.Palette.accent)
                .frame(width: 6, height: 6)
                .opacity(isActive ? 1 : 0)
                .accessibilityHidden(true)
            Text(tab.title)
                .font(HerminalDesign.Typography.monoCaption)
                .foregroundStyle(
                    isActive
                        ? HerminalDesign.Palette.textPrimary
                        : HerminalDesign.Palette.textSecondary
                )
                .lineLimit(1)
                .truncationMode(.middle)
            // Pushes the title to the leading edge and the close button to
            // the trailing one. Without it the HStack sizes to its content
            // and the frame centres the whole group, which reads as a
            // floating label rather than a tab.
            Spacer(minLength: HerminalDesign.Spacing.xs)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(
                        isCloseHovered
                            ? HerminalDesign.Palette.textPrimary
                            : HerminalDesign.Palette.textTertiary
                    )
                    .padding(3)
                    .background(
                        Circle()
                            .fill(isCloseHovered
                                  ? HerminalDesign.Palette.surfaceOverlay
                                  : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isCloseHovered = $0 }
            .accessibilityLabel("Close tab \(tab.title)")
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .frame(height: 26)
        .frame(minWidth: 96, maxWidth: 200)
        .background(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .strokeBorder(isActive ? HerminalDesign.Palette.border : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        // v0.3 polish: inactive tabs fade to background so the active
        // tab reads as the focus point, not "one of N equal chips".
        // Hover restores full opacity so the click target is obvious.
        .opacity(isActive || isHovered ? 1.0 : HerminalDesign.Geometry.tabInactiveOpacity)
        // Spring-curve hover transition feels alive vs. the previous
        // linear .easeOut. Both hover and opacity ride the same animation
        // so they arrive together.
        .animation(
            .spring(
                response: HerminalDesign.Motion.springResponse,
                dampingFraction: HerminalDesign.Motion.springDamping
            ),
            value: isHovered
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tab \(tab.title)\(isActive ? ", active" : "")")
    }

    private var backgroundFill: Color {
        if isActive { return HerminalDesign.Palette.surfaceOverlay }
        if isHovered { return HerminalDesign.Palette.surfaceOverlay.opacity(0.5) }
        return .clear
    }
}

/// New-tab `+` button with the same hover treatment as the SSH panel's
/// add button — keeps the iconography consistent across the app.
private struct NewTabButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isHovered
                                 ? HerminalDesign.Palette.accent
                                 : HerminalDesign.Palette.textSecondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                        .fill(isHovered
                              ? HerminalDesign.Palette.surfaceOverlay
                              : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: HerminalDesign.Motion.fast), value: isHovered)
        .accessibilityLabel("New tab")
    }
}
