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
            Spacer()
            Text("\(agents.count)")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
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
                .fill(HerminalDesign.Palette.statusRunning)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.label(for: agent.kind))
                    .font(HerminalDesign.Typography.bodyEmphasis)
                    .foregroundStyle(HerminalDesign.Palette.textPrimary)
                Text("pid \(agent.pid) · running")
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
