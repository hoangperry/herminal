// PanelChrome — the shared furniture every sidebar panel puts around its
// content: the title strip at the top and the empty state underneath.
//
// The agent dashboard, the SSH host manager and the Claude session browser
// occupy the same slot and are toggled between, so any disagreement in
// their title tracking, leading rail or empty-state hierarchy reads as
// three different panels rather than three views of one sidebar. They each
// grew their own copy of that furniture; this is the single definition.

import AppKit
import SwiftUI

/// Stable spoken names for native AppKit controls embedded in modal alerts.
/// Placeholders remain visual examples; assistive technology gets a durable
/// label that does not disappear when the user enters a value.
enum ModalControlAccessibility {
    enum Labels {
        static let workspaceName = "Workspace name"
        static let tmuxSessionName = "tmux session name"
        static let tmuxSessionPicker = "Session to attach"
        static let worktreeBranchName = "Worktree branch name"
        static let agentKind = "Agent kind"
    }

    /// Applies the spoken name and, when requested, makes the control the
    /// first keyboard target in its alert. Returning the same instance keeps
    /// native prompt construction compact and makes the wiring testable.
    @discardableResult
    @MainActor
    static func prepare<Control: NSView>(
        _ control: Control,
        label: String,
        initialResponderIn alert: NSAlert? = nil
    ) -> Control {
        control.setAccessibilityLabel(label)
        alert?.window.initialFirstResponder = control
        return control
    }
}

/// `@MainActor` because it builds SwiftUI views and reads
/// `TabBarView.barHeight`, both of which are main-actor isolated — same
/// isolation as every panel that calls in here.
@MainActor
enum PanelChrome {
    enum ActionProminence: Equatable {
        case primary
        case secondary
    }

    struct EmptyStateAction<ActionID: Hashable>: Identifiable, Equatable {
        let id: ActionID
        let title: String
        let systemImage: String
        let accessibilityLabel: String
        let accessibilityHint: String
        let prominence: ActionProminence

        init(
            id: ActionID,
            title: String,
            systemImage: String,
            accessibilityLabel: String? = nil,
            accessibilityHint: String,
            prominence: ActionProminence = .secondary
        ) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
            self.accessibilityLabel = accessibilityLabel ?? title
            self.accessibilityHint = accessibilityHint
            self.prominence = prominence
        }
    }

    struct EmptyStateContent<ActionID: Hashable>: Equatable {
        let headline: String
        let detail: String
        let actions: [EmptyStateAction<ActionID>]
    }

    /// Leading rail shared by every panel's title and its rows.
    ///
    /// A panel's list carries `Spacing.sm` around the stack and another
    /// `Spacing.sm` inside each row, so row content starts at 16. The title
    /// sits on the same rail, which also keeps the header's trailing buttons
    /// off the panel edge.
    static let rail = HerminalDesign.Spacing.lg
    static let minimumInteractiveControlSize = HerminalDesign.Geometry.minimumInteractiveControlSize
    static let compactInteractiveControlSize = HerminalDesign.Geometry.compactInteractiveControlSize

    /// The title strip: uppercase label on the leading rail, caller-supplied
    /// trailing controls, one tab-bar height tall so it lines up with the
    /// tab strip across the window.
    static func header<Trailing: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: HerminalDesign.Spacing.xs) {
            Text(title)
                .font(HerminalDesign.Typography.caption)
                .tracking(HerminalDesign.Typography.headerTracking)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, rail)
        .frame(height: TabBarView.barHeight)
    }

    /// Panel-level empty state. The headline is `body` and the explanation
    /// `caption` — deliberately two sizes, so an empty panel still has a
    /// hierarchy to read instead of two equal grey lines.
    static func emptyState(_ headline: String, _ detail: String) -> some View {
        emptyStateLayout(headline, detail) {
            EmptyView()
        }
    }

    static func emptyState<ActionID: Hashable>(
        _ content: EmptyStateContent<ActionID>,
        initiallyFocusedActionID: ActionID? = nil,
        onAction: @escaping (ActionID) -> Void
    ) -> some View {
        emptyStateLayout(content.headline, content.detail) {
            VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xs) {
                ForEach(content.actions) { action in
                    EmptyStateActionButton(
                        action: action,
                        requestsInitialFocus: action.id == initiallyFocusedActionID
                    ) {
                        onAction(action.id)
                    }
                }
            }
            .padding(.top, HerminalDesign.Spacing.sm)
        }
    }

    private static func emptyStateLayout<Actions: View>(
        _ headline: String,
        _ detail: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xs) {
            Text(headline)
                .font(HerminalDesign.Typography.body)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .accessibilityAddTraits(.isHeader)
            // Parse the detail as markdown. Taking it as a `String` means
            // Text uses the plain initializer, not LocalizedStringKey, so a
            // code span reached the screen as literal backticks around the
            // word — "Run `claude` in any project" with the ticks showing,
            // which reads as a typo.
            Text((try? AttributedString(markdown: detail)) ?? AttributedString(detail))
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            actions()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, rail)
        .padding(.vertical, HerminalDesign.Spacing.md)
    }
}

private struct EmptyStateActionButton<ActionID: Hashable>: View {
    let action: PanelChrome.EmptyStateAction<ActionID>
    let requestsInitialFocus: Bool
    let perform: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    private var isEmphasized: Bool {
        isHovered || isFocused
    }

    private var iconColor: Color {
        if action.prominence == .primary || isEmphasized {
            HerminalDesign.Palette.accent
        } else {
            HerminalDesign.Palette.textSecondary
        }
    }

    private var labelColor: Color {
        action.prominence == .primary
            ? HerminalDesign.Palette.textPrimary
            : HerminalDesign.Palette.textSecondary
    }

    private var backgroundColor: Color {
        switch action.prominence {
        case .primary:
            return HerminalDesign.Palette.accent.opacity(isEmphasized ? 0.18 : 0.12)
        case .secondary:
            return isEmphasized
                ? HerminalDesign.Palette.surfaceOverlay
                : HerminalDesign.Palette.surfaceOverlay.opacity(0.7)
        }
    }

    private var borderColor: Color {
        switch action.prominence {
        case .primary:
            return HerminalDesign.Palette.accent.opacity(isEmphasized ? 0.48 : 0.24)
        case .secondary:
            return isEmphasized ? HerminalDesign.Palette.accent.opacity(0.45) : .clear
        }
    }

    var body: some View {
        Button(action: perform) {
            HStack(spacing: HerminalDesign.Spacing.xs) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)
                Text(action.title)
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(labelColor)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, HerminalDesign.Spacing.sm)
            .frame(
                maxWidth: .infinity,
                minHeight: PanelChrome.minimumInteractiveControlSize,
                alignment: .leading
            )
            .background(
                RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onAppear {
            guard requestsInitialFocus else { return }
            DispatchQueue.main.async { isFocused = true }
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: HerminalDesign.Motion.fast), value: isEmphasized)
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityHint(action.accessibilityHint)
    }
}
