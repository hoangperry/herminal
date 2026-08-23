import SwiftUI

enum SSHImportFeedback: Equatable, Sendable {
    static let minimumInteractiveControlSize = HerminalDesign.Geometry.minimumInteractiveControlSize

    enum Tone: Equatable, Sendable {
        case progress
        case success
        case notice
        case error
    }

    enum RecoveryAction: Equatable, Sendable {
        case addHost
        case retry

        var title: String {
            switch self {
            case .addHost: "Add Host"
            case .retry: "Try Again"
            }
        }

        var accessibilityHint: String {
            switch self {
            case .addHost: "Opens the inline form for a new saved host"
            case .retry: "Reads your SSH config again"
            }
        }
    }

    struct Content: Equatable, Sendable {
        let tone: Tone
        let systemImage: String
        let title: String
        let detail: String
        let recoveryAction: RecoveryAction?

        var accessibilityLabel: String {
            "\(title). \(detail)"
        }
    }

    case importing
    case imported(count: Int)
    case noConcreteHosts
    case configMissing
    case fileTooLarge
    case failed

    static func result(importedCount: Int) -> Self {
        importedCount > 0 ? .imported(count: importedCount) : .noConcreteHosts
    }

    var isImporting: Bool {
        self == .importing
    }

    func content(storageIsDurable: Bool) -> Content {
        switch self {
        case .importing:
            Content(
                tone: .progress,
                systemImage: "arrow.triangle.2.circlepath",
                title: "Importing SSH config…",
                detail: "Reading concrete Host entries from ~/.ssh/config.",
                recoveryAction: nil
            )
        case .imported(let count):
            Content(
                tone: .success,
                systemImage: "checkmark.circle.fill",
                title: "Imported \(count) host\(count == 1 ? "" : "s")",
                detail: storageIsDurable
                    ? "Your SSH hosts are ready to connect."
                    : "Ready to connect until Herminal quits.",
                recoveryAction: nil
            )
        case .noConcreteHosts:
            Content(
                tone: .notice,
                systemImage: "info.circle.fill",
                title: "No importable hosts found",
                detail: "Add a concrete Host entry to ~/.ssh/config. Wildcard and Match rules are skipped.",
                recoveryAction: .addHost
            )
        case .configMissing:
            Content(
                tone: .notice,
                systemImage: "doc.badge.questionmark",
                title: "SSH config not found",
                detail: "Create ~/.ssh/config, or save a connection manually.",
                recoveryAction: .addHost
            )
        case .fileTooLarge:
            Content(
                tone: .error,
                systemImage: "exclamationmark.triangle.fill",
                title: "SSH config is too large",
                detail: "Herminal imports files up to 1 MB. Reduce the file, then try again.",
                recoveryAction: .retry
            )
        case .failed:
            Content(
                tone: .error,
                systemImage: "exclamationmark.triangle.fill",
                title: "Couldn’t import SSH config",
                detail: "Check that ~/.ssh/config is readable, then try again.",
                recoveryAction: .retry
            )
        }
    }

    var content: Content {
        content(storageIsDurable: true)
    }
}

struct SSHImportState: Equatable, Sendable {
    private(set) var feedback: SSHImportFeedback?
    private(set) var isImporting = false

    mutating func begin() -> Bool {
        guard !isImporting else { return false }
        isImporting = true
        feedback = .importing
        return true
    }

    mutating func complete(with feedback: SSHImportFeedback) {
        self.feedback = feedback
        isImporting = false
    }

    mutating func clearAfterManualHostSave() {
        guard !isImporting else { return }
        feedback = nil
    }

    mutating func dismiss() {
        guard !isImporting else { return }
        feedback = nil
    }
}

struct SSHImportFeedbackView: View {
    let feedback: SSHImportFeedback
    let storageIsDurable: Bool
    let showsRecoveryAction: Bool
    let onRecovery: (SSHImportFeedback.RecoveryAction) -> Void
    let onDismiss: () -> Void

    private var content: SSHImportFeedback.Content {
        feedback.content(storageIsDurable: storageIsDurable)
    }

    private var tint: Color {
        switch content.tone {
        case .progress: HerminalDesign.Palette.statusRunning
        case .success: HerminalDesign.Palette.statusDone
        case .notice: HerminalDesign.Palette.accent
        case .error: HerminalDesign.Palette.statusError
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: HerminalDesign.Spacing.xs) {
            statusIcon
                .frame(width: 16, height: 16)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xxs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(content.title)
                        .font(HerminalDesign.Typography.caption)
                        .foregroundStyle(HerminalDesign.Palette.textPrimary)
                    Text(content.detail)
                        .font(HerminalDesign.Typography.caption)
                        .foregroundStyle(HerminalDesign.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(content.accessibilityLabel)

                if showsRecoveryAction, let action = content.recoveryAction {
                    Button(action.title) { onRecovery(action) }
                        .font(HerminalDesign.Typography.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(tint)
                        .frame(minHeight: SSHImportFeedback.minimumInteractiveControlSize)
                        .contentShape(Rectangle())
                        .accessibilityHint(action.accessibilityHint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !feedback.isImporting {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(
                            width: SSHImportFeedback.minimumInteractiveControlSize,
                            height: SSHImportFeedback.minimumInteractiveControlSize
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityLabel("Dismiss SSH import status")
                .accessibilityHint("Hides this import result")
            }
        }
        .padding(HerminalDesign.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .strokeBorder(tint.opacity(0.30), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        if feedback.isImporting {
            ProgressView()
                .controlSize(.small)
                .tint(tint)
        } else {
            Image(systemName: content.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
        }
    }
}
