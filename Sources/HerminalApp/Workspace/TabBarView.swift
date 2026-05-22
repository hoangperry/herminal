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
                tabChip(tab)
            }
            newButton
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

    private func tabChip(_ tab: Tab) -> some View {
        let isActive = tab.id == activeID
        return HStack(spacing: HerminalDesign.Spacing.xs) {
            Text(tab.title)
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(
                    isActive
                        ? HerminalDesign.Palette.textPrimary
                        : HerminalDesign.Palette.textSecondary
                )
                .lineLimit(1)
            Button {
                onClose(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(HerminalDesign.Palette.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .frame(height: 26)
        .frame(minWidth: 96, maxWidth: 200)
        .background(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .fill(isActive ? HerminalDesign.Palette.surfaceOverlay : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .strokeBorder(isActive ? HerminalDesign.Palette.border : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect(tab.id) }
    }

    private var newButton: some View {
        Button(action: onNew) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
