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
        .padding(.horizontal, HerminalDesign.Spacing.sm)
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
            Text(tab.title)
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(
                    isActive
                        ? HerminalDesign.Palette.textPrimary
                        : HerminalDesign.Palette.textSecondary
                )
                .lineLimit(1)
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
        .animation(.easeOut(duration: HerminalDesign.Motion.fast), value: isHovered)
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
