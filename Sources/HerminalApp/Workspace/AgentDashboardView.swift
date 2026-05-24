// AgentDashboardView — sidebar panel listing the agent CLIs running under
// herminal. SwiftUI chrome styled from design tokens.
//
// Alpha scope: every detected agent is shown as "running" (a detected process
// is, by definition, alive). Running/idle/done discrimination needs CPU /
// process-state sampling — deferred (see docs/backlog/month-3.md).

import SwiftUI
import HerminalAgent

struct AgentDashboardView: View {
    let agents: [DetectedAgent]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HerminalDesign.Palette.divider)
            if agents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xxs) {
                        ForEach(agents) { agent in
                            agentRow(agent)
                        }
                    }
                    .padding(HerminalDesign.Spacing.sm)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HerminalDesign.Palette.surfaceElevated)
    }

    private var header: some View {
        HStack {
            Text("AGENTS")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text("\(agents.count)")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .accessibilityLabel("\(agents.count) agent\(agents.count == 1 ? "" : "s") running")
        }
        .padding(.horizontal, HerminalDesign.Spacing.md)
        .frame(height: TabBarView.barHeight)
    }

    private var emptyState: some View {
        Text("No agents running")
            .font(HerminalDesign.Typography.caption)
            .foregroundStyle(HerminalDesign.Palette.textTertiary)
            .padding(HerminalDesign.Spacing.md)
    }

    private func agentRow(_ agent: DetectedAgent) -> some View {
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
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .padding(.vertical, HerminalDesign.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .fill(HerminalDesign.Palette.surfaceOverlay)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Self.label(for: agent.kind)) agent \(Self.statusText(agent.status)), pid \(agent.pid)")
    }

    private static func color(for status: AgentStatus) -> Color {
        switch status {
        case .running: HerminalDesign.Palette.statusRunning
        case .idle: HerminalDesign.Palette.statusIdle
        case .needsInput: HerminalDesign.Palette.statusRunning
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
