import SwiftUI
import HerminalAgent

@MainActor
enum AgentDashboardRowChrome {
    struct Presentation: Equatable {
        let isEmphasized: Bool
        let showsFocusStroke: Bool
        let minimumHeight: CGFloat
    }

    static func presentation(isHovered: Bool, isFocused: Bool) -> Presentation {
        Presentation(
            isEmphasized: isHovered || isFocused,
            showsFocusStroke: isFocused,
            minimumHeight: AgentDashboardView.rowMinimumHeight
        )
    }

    static func shouldAnimate(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}

struct AgentDashboardRow: View {
    let agent: DetectedAgent
    let requestsInitialFocus: Bool
    let onSelect: () -> Void
    let onInitialFocusApplied: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isActionable: Bool { agent.tabHint != nil }
    private var chrome: AgentDashboardRowChrome.Presentation {
        AgentDashboardRowChrome.presentation(isHovered: isHovered, isFocused: isFocused)
    }

    var body: some View {
        if isActionable {
            Button(action: onSelect) {
                rowContent(chrome: chrome)
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .onAppear {
                guard requestsInitialFocus else { return }
                DispatchQueue.main.async {
                    isFocused = true
                    onInitialFocusApplied()
                }
            }
            .onHover { isHovered = $0 }
            .animation(
                AgentDashboardRowChrome.shouldAnimate(reduceMotion: reduceMotion)
                    ? .easeOut(duration: HerminalDesign.Motion.fast)
                    : nil,
                value: chrome.isEmphasized
            )
            .accessibilityLabel(Self.primaryActionAccessibilityLabel(for: agent))
            .accessibilityValue(Self.primaryActionAccessibilityValue(for: agent))
            .accessibilityHint(Self.primaryActionAccessibilityHint)
        } else {
            rowContent(chrome: AgentDashboardRowChrome.presentation(
                isHovered: false,
                isFocused: false
            ))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.statusAccessibilityLabel(for: agent))
        }
    }

    private func rowContent(chrome: AgentDashboardRowChrome.Presentation) -> some View {
        HStack(spacing: HerminalDesign.Spacing.sm) {
            Circle()
                .fill(Self.color(for: agent.status))
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.label(for: agent.kind))
                    .font(HerminalDesign.Typography.bodyEmphasis)
                    .foregroundStyle(HerminalDesign.Palette.textPrimary)
                Text("pid \(agent.pid) · \(Self.statusText(agent.status))")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textTertiary)
            }
            Spacer(minLength: 0)
            if let tab = agent.tabHint {
                Text("Pane \(tab + 1)")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
                    .padding(.horizontal, HerminalDesign.Spacing.xs)
                    .padding(.vertical, HerminalDesign.Spacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                            .fill(HerminalDesign.Palette.surfaceOverlay)
                    )
            }
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .padding(.vertical, HerminalDesign.Spacing.xs)
        .frame(
            maxWidth: .infinity,
            minHeight: chrome.minimumHeight,
            alignment: .leading
        )
        .background(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .fill(chrome.isEmphasized ? HerminalDesign.Palette.surfaceOverlay : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .strokeBorder(
                    chrome.showsFocusStroke
                        ? HerminalDesign.Palette.accent.opacity(0.55)
                        : .clear,
                    lineWidth: 1
                )
        )
        .overlay(alignment: .bottom) {
            HerminalDesign.Palette.divider.frame(height: 1)
        }
        .contentShape(Rectangle())
    }

    static func primaryActionAccessibilityLabel(for agent: DetectedAgent) -> String {
        guard let tab = agent.tabHint else { return statusAccessibilityLabel(for: agent) }
        return "Focus Pane \(tab + 1) for \(label(for: agent.kind)) agent"
    }

    static func primaryActionAccessibilityValue(for agent: DetectedAgent) -> String {
        "\(statusText(agent.status)), pid \(agent.pid)"
    }

    static let primaryActionAccessibilityHint =
        "Press Return or Space to focus the mapped terminal pane"

    private static func statusAccessibilityLabel(for agent: DetectedAgent) -> String {
        "\(label(for: agent.kind)) agent \(statusText(agent.status)), pid \(agent.pid), no mapped pane"
    }

    private static func color(for status: AgentStatus) -> Color {
        switch status {
        case .running: HerminalDesign.Palette.statusRunning
        case .idle: HerminalDesign.Palette.statusIdle
        case .needsInput: HerminalDesign.Palette.statusNeedsInput
        case .exitedSuccess: HerminalDesign.Palette.statusDone
        case .exitedError: HerminalDesign.Palette.statusError
        case .unknown: HerminalDesign.Palette.statusIdle
        }
    }

    private static func statusText(_ status: AgentStatus) -> String {
        switch status {
        case .running: "running"
        case .idle: "idle"
        case .needsInput: "needs input"
        case .exitedSuccess: "done"
        case .exitedError: "error"
        case .unknown: "starting"
        }
    }

    private static func label(for kind: AgentKind) -> String {
        switch kind {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .aider: "Aider"
        case .unknown: "Agent"
        }
    }
}

struct AgentDashboardPrimaryRowButton<Content: View>: View {
    let presentation: AgentDashboardView.PrimaryRowActionPresentation
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var chrome: AgentDashboardRowChrome.Presentation {
        AgentDashboardRowChrome.presentation(isHovered: isHovered, isFocused: isFocused)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: HerminalDesign.Spacing.xs) {
                if presentation.includesLeadingIconInPrimaryHitRegion {
                    Image(systemName: presentation.leadingIconSystemName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(HerminalDesign.Palette.accent)
                        .accessibilityHidden(true)
                }
                content()
            }
            .frame(
                maxWidth: .infinity,
                minHeight: presentation.minimumHeight,
                alignment: .leading
            )
            .background(
                RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                    .fill(chrome.isEmphasized ? HerminalDesign.Palette.surfaceOverlay : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                    .strokeBorder(
                        chrome.showsFocusStroke
                            ? HerminalDesign.Palette.accent.opacity(0.55)
                            : .clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .animation(
            AgentDashboardRowChrome.shouldAnimate(reduceMotion: reduceMotion)
                ? .easeOut(duration: HerminalDesign.Motion.fast)
                : nil,
            value: chrome.isEmphasized
        )
        .accessibilityLabel(presentation.accessibility.label)
        .accessibilityHint(presentation.accessibility.hint)
    }
}

struct AgentDashboardIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let controlSize: CGFloat
    var accessibilityHint: String? = nil
    let action: (() -> Void)?

    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEmphasized: Bool { isHovered || isFocused }

    var body: some View {
        Button { action?() } label: {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(
                    isEmphasized
                        ? HerminalDesign.Palette.accent
                        : HerminalDesign.Palette.textSecondary
                )
                .frame(width: controlSize, height: controlSize)
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
        .disabled(action == nil)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .animation(
            AgentDashboardRowChrome.shouldAnimate(reduceMotion: reduceMotion)
                ? .easeOut(duration: HerminalDesign.Motion.fast)
                : nil,
            value: isEmphasized
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(ifPresent: accessibilityHint)
    }
}

private extension View {
    @ViewBuilder
    func accessibilityHint(ifPresent hint: String?) -> some View {
        if let hint {
            accessibilityHint(hint)
        } else {
            self
        }
    }
}

struct AgentDashboardTextButton: View {
    let title: String
    let accessibilityLabel: String
    let action: (() -> Void)?

    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEmphasized: Bool { isHovered || isFocused }

    var body: some View {
        Button { action?() } label: {
            Text(title)
                .font(HerminalDesign.Typography.monoCaption)
                .foregroundStyle(
                    isEmphasized
                        ? HerminalDesign.Palette.accent
                        : HerminalDesign.Palette.textSecondary
                )
                .padding(.horizontal, HerminalDesign.Spacing.xs)
                .frame(
                    minWidth: AgentDashboardView.compactInteractiveControlSize,
                    minHeight: AgentDashboardView.compactInteractiveControlSize
                )
                .background(
                    RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                        .fill(HerminalDesign.Palette.surfaceOverlay)
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
        .disabled(action == nil)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .animation(
            AgentDashboardRowChrome.shouldAnimate(reduceMotion: reduceMotion)
                ? .easeOut(duration: HerminalDesign.Motion.fast)
                : nil,
            value: isEmphasized
        )
        .accessibilityLabel(accessibilityLabel)
    }
}
