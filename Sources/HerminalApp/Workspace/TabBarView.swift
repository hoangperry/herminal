// TabBarView — the workspace tab strip. SwiftUI chrome styled from design tokens.
// Stateless: WorkspaceView rebuilds it whenever sessions or selection change.

import SwiftUI

struct TabBarView: View {
    static let barHeight: CGFloat = 36
    static let compactInteractiveControlSize =
        HerminalDesign.Geometry.compactInteractiveControlSize
    static let minimumTabWidth: CGFloat = 96
    static let maximumTabWidth: CGFloat = 200

    struct TabAccessibilityPresentation: Equatable {
        let label: String
        let value: String?
        let hint: String
    }

    struct ActionAccessibilityPresentation: Equatable {
        let label: String
        let hint: String
    }

    struct Tab: Identifiable {
        let id: UUID
        let title: String
    }

    enum FocusTarget: Hashable {
        case tab(UUID)
        case close(UUID)
        case newTab
    }

    static func tabAccessibilityPresentation(
        title: String,
        isActive: Bool
    ) -> TabAccessibilityPresentation {
        TabAccessibilityPresentation(
            label: "Tab \(title)",
            value: isActive ? "Selected" : nil,
            hint: "Press Return or Space to select this tab"
        )
    }

    static func closeTabAccessibilityPresentation(
        title: String
    ) -> ActionAccessibilityPresentation {
        ActionAccessibilityPresentation(
            label: "Close tab \(title)",
            hint: "Closes this terminal tab"
        )
    }

    static let newTabAccessibilityPresentation = ActionAccessibilityPresentation(
        label: "New tab",
        hint: "Opens a new terminal tab"
    )

    static func shouldDimTab(
        isActive: Bool,
        isHovered: Bool,
        isSelectionFocused: Bool,
        isCloseFocused: Bool
    ) -> Bool {
        !isActive && !isHovered && !isSelectionFocused && !isCloseFocused
    }

    static func shouldAnimateFocusTransition(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    let tabs: [Tab]
    let activeID: UUID?
    /// Space to keep clear at the leading edge for the window's traffic
    /// lights. The strip's *background* still spans the full width so the
    /// titlebar row reads as one continuous surface; only the chips move.
    var leadingInset: CGFloat = 0
    var initialFocusTarget: FocusTarget? = nil
    var onFocusChange: (FocusTarget, Bool) -> Void = { _, _ in }
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onNew: () -> Void

    var body: some View {
        HStack(spacing: HerminalDesign.Spacing.xxs) {
            ForEach(tabs) { tab in
                TabChip(tab: tab,
                        isActive: tab.id == activeID,
                        initialFocusTarget: initialFocusTarget,
                        onFocusChange: onFocusChange,
                        onSelect: { onSelect(tab.id) },
                        onClose: { onClose(tab.id) })
            }
            NewTabButton(
                requestsInitialFocus: initialFocusTarget == .newTab,
                onFocusChange: onFocusChange,
                action: onNew
            )
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
    let initialFocusTarget: TabBarView.FocusTarget?
    let onFocusChange: (TabBarView.FocusTarget, Bool) -> Void
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @State private var isCloseHovered = false
    @FocusState private var isSelectionFocused: Bool
    @FocusState private var isCloseFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tabAccessibility: TabBarView.TabAccessibilityPresentation {
        TabBarView.tabAccessibilityPresentation(title: tab.title, isActive: isActive)
    }

    private var closeAccessibility: TabBarView.ActionAccessibilityPresentation {
        TabBarView.closeTabAccessibilityPresentation(title: tab.title)
    }

    private var isCloseEmphasized: Bool {
        isCloseHovered || isCloseFocused
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: HerminalDesign.Spacing.xs) {
                    // The active dot is always laid out and only faded, so
                    // switching tabs never changes chip width or reflows the strip.
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
                    Spacer(minLength: HerminalDesign.Spacing.xs)
                }
                .padding(.leading, HerminalDesign.Spacing.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($isSelectionFocused)
            .accessibilityLabel(tabAccessibility.label)
            .accessibilityValue(ifPresent: tabAccessibility.value)
            .accessibilityHint(tabAccessibility.hint)
            .accessibilityAddTraits(isActive ? .isSelected : [])

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(
                        isCloseEmphasized
                            ? HerminalDesign.Palette.textPrimary
                            : HerminalDesign.Palette.textTertiary
                    )
                    .frame(
                        width: TabBarView.compactInteractiveControlSize,
                        height: TabBarView.compactInteractiveControlSize
                    )
                    .background(
                        Circle()
                            .fill(isCloseEmphasized
                                  ? HerminalDesign.Palette.surfaceOverlay
                                  : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                            .strokeBorder(
                                isCloseFocused
                                    ? HerminalDesign.Palette.accent.opacity(0.55)
                                    : .clear,
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
            .focused($isCloseFocused)
            .onHover { isCloseHovered = $0 }
            .accessibilityLabel(closeAccessibility.label)
            .accessibilityHint(closeAccessibility.hint)
        }
        .frame(height: TabBarView.compactInteractiveControlSize)
        .frame(
            minWidth: TabBarView.minimumTabWidth,
            maxWidth: TabBarView.maximumTabWidth
        )
        .background(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .strokeBorder(selectionBorderColor, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        // v0.3 polish: inactive tabs fade to background so the active
        // tab reads as the focus point, not "one of N equal chips".
        // Hover restores full opacity so the click target is obvious.
        .opacity(
            shouldDim
                ? HerminalDesign.Geometry.tabInactiveOpacity
                : 1.0
        )
        // Spring-curve hover transition feels alive vs. the previous
        // linear .easeOut. Both hover and opacity ride the same animation
        // so they arrive together.
        .animation(
            TabBarView.shouldAnimateFocusTransition(reduceMotion: reduceMotion)
                ? .spring(
                    response: HerminalDesign.Motion.springResponse,
                    dampingFraction: HerminalDesign.Motion.springDamping
                )
                : nil,
            value: shouldDim
        )
        .onChange(of: isSelectionFocused) { _, isFocused in
            onFocusChange(.tab(tab.id), isFocused)
        }
        .onChange(of: isCloseFocused) { _, isFocused in
            onFocusChange(.close(tab.id), isFocused)
        }
        .onAppear {
            guard let initialFocusTarget else { return }
            DispatchQueue.main.async {
                if initialFocusTarget == .tab(tab.id) {
                    isSelectionFocused = true
                } else if initialFocusTarget == .close(tab.id) {
                    isCloseFocused = true
                }
            }
        }
    }

    private var shouldDim: Bool {
        TabBarView.shouldDimTab(
            isActive: isActive,
            isHovered: isHovered,
            isSelectionFocused: isSelectionFocused,
            isCloseFocused: isCloseFocused
        )
    }

    private var selectionBorderColor: Color {
        if isSelectionFocused { return HerminalDesign.Palette.accent.opacity(0.55) }
        if isActive { return HerminalDesign.Palette.border }
        return .clear
    }

    private var backgroundFill: Color {
        if isActive { return HerminalDesign.Palette.surfaceOverlay }
        if isHovered { return HerminalDesign.Palette.surfaceOverlay.opacity(0.5) }
        return .clear
    }
}

private extension View {
    @ViewBuilder
    func accessibilityValue(ifPresent value: String?) -> some View {
        if let value {
            accessibilityValue(value)
        } else {
            self
        }
    }
}

/// New-tab `+` button with the same hover treatment as the SSH panel's
/// add button — keeps the iconography consistent across the app.
private struct NewTabButton: View {
    let requestsInitialFocus: Bool
    let onFocusChange: (TabBarView.FocusTarget, Bool) -> Void
    let action: () -> Void
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEmphasized: Bool {
        isHovered || isFocused
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isEmphasized
                                 ? HerminalDesign.Palette.accent
                                 : HerminalDesign.Palette.textSecondary)
                .frame(
                    width: TabBarView.compactInteractiveControlSize,
                    height: TabBarView.compactInteractiveControlSize
                )
                .background(
                    RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                        .fill(isEmphasized
                              ? HerminalDesign.Palette.surfaceOverlay
                              : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                        .strokeBorder(
                            isFocused
                                ? HerminalDesign.Palette.accent.opacity(0.55)
                                : .clear,
                            lineWidth: 1
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onChange(of: isFocused) { _, isFocused in
            onFocusChange(.newTab, isFocused)
        }
        .onHover { isHovered = $0 }
        .animation(
            TabBarView.shouldAnimateFocusTransition(reduceMotion: reduceMotion)
                ? .easeOut(duration: HerminalDesign.Motion.fast)
                : nil,
            value: isEmphasized
        )
        .accessibilityLabel(TabBarView.newTabAccessibilityPresentation.label)
        .accessibilityHint(TabBarView.newTabAccessibilityPresentation.hint)
        .onAppear {
            guard requestsInitialFocus else { return }
            DispatchQueue.main.async {
                isFocused = true
            }
        }
    }
}
