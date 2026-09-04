import AppKit

enum SupportIssueOpenOutcome: Equatable {
    case opened
    case failed
}

struct SupportIssueOpenFailureAlert: Equatable {
    let messageText: String
    let informativeText: String
    let manualRecoveryURL: URL?
    let copyButtonTitle: String
    let cancelButtonTitle: String
}

enum SupportIssueReporter {
    static let bugReportURL = URL(
        string: "https://github.com/hoangperry/herminal/issues/new?template=bug_report.md"
    )!
    static let betaFeedbackURL = URL(
        string: "https://github.com/hoangperry/herminal/issues/new?template=beta_report.yml"
    )!
    static let featureRequestURL = URL(
        string: "https://github.com/hoangperry/herminal/issues/new?template=feature_request.md"
    )!
    static let contributorGuideURL = URL(
        string: "https://github.com/hoangperry/herminal/blob/main/CONTRIBUTING.md"
    )!

    static let openFailureAlert = SupportIssueOpenFailureAlert(
        messageText: "Couldn’t Open the Bug Report",
        informativeText:
            "Visit github.com/hoangperry/herminal/issues/new in your browser. "
            + "Before filing, choose Help > Copy Redacted Diagnostics for Bug Report. "
            + "Review the copied text before pasting it.",
        manualRecoveryURL: nil,
        copyButtonTitle: "Copy Bug Report URL",
        cancelButtonTitle: "Close"
    )

    static let betaFeedbackOpenFailureAlert = SupportIssueOpenFailureAlert(
        messageText: "Couldn’t Open Beta Feedback",
        informativeText:
            "Choose Copy Beta Feedback URL, or open this address manually in any browser:\n"
            + betaFeedbackURL.absoluteString
            + "\n"
            + "Review every field before submitting; do not include private terminal data or credentials.",
        manualRecoveryURL: nil,
        copyButtonTitle: "Copy Beta Feedback URL",
        cancelButtonTitle: "Close"
    )

    static let featureRequestOpenFailureAlert = SupportIssueOpenFailureAlert(
        messageText: "Couldn’t Open the Feature Request",
        informativeText:
            "Choose Copy Feature Request URL, then paste it into any browser. "
            + "Describe the problem without including private terminal data or credentials.",
        manualRecoveryURL: featureRequestURL,
        copyButtonTitle: "Copy Feature Request URL",
        cancelButtonTitle: "Close"
    )

    static let contributorGuideOpenFailureAlert = SupportIssueOpenFailureAlert(
        messageText: "Couldn’t Open the Contributor Guide",
        informativeText:
            "Choose Copy Contributor Guide URL, then paste it into any browser.",
        manualRecoveryURL: contributorGuideURL,
        copyButtonTitle: "Copy Contributor Guide URL",
        cancelButtonTitle: "Close"
    )

    static func openBugReport(
        using opener: (URL) -> Bool
    ) -> SupportIssueOpenOutcome {
        open(bugReportURL, using: opener)
    }

    static func openBetaFeedback(
        using opener: (URL) -> Bool
    ) -> SupportIssueOpenOutcome {
        open(betaFeedbackURL, using: opener)
    }

    static func openFeatureRequest(
        using opener: (URL) -> Bool
    ) -> SupportIssueOpenOutcome {
        open(featureRequestURL, using: opener)
    }

    static func openContributorGuide(
        using opener: (URL) -> Bool
    ) -> SupportIssueOpenOutcome {
        open(contributorGuideURL, using: opener)
    }

    @MainActor
    static func copyBugReportURL(
        to pasteboard: NSPasteboard = .general
    ) -> DiagnosticDiaryClipboard.Outcome {
        copy(bugReportURL, to: pasteboard)
    }

    @MainActor
    static func copyBetaFeedbackURL(
        to pasteboard: NSPasteboard = .general
    ) -> DiagnosticDiaryClipboard.Outcome {
        copy(betaFeedbackURL, to: pasteboard)
    }

    @MainActor
    static func copyFeatureRequestURL(
        to pasteboard: NSPasteboard = .general
    ) -> DiagnosticDiaryClipboard.Outcome {
        copy(featureRequestURL, to: pasteboard)
    }

    @MainActor
    static func copyContributorGuideURL(
        to pasteboard: NSPasteboard = .general
    ) -> DiagnosticDiaryClipboard.Outcome {
        copy(contributorGuideURL, to: pasteboard)
    }

    private static func open(
        _ destination: URL,
        using opener: (URL) -> Bool
    ) -> SupportIssueOpenOutcome {
        opener(destination) ? .opened : .failed
    }

    @MainActor
    private static func copy(
        _ destination: URL,
        to pasteboard: NSPasteboard
    ) -> DiagnosticDiaryClipboard.Outcome {
        DiagnosticDiaryClipboard.write(destination.absoluteString, to: pasteboard)
    }
}

@MainActor
enum DiagnosticDiaryClipboard {
    enum Outcome: Equatable {
        case copied
        case empty
        case failed
    }

    struct Feedback: Equatable {
        let announcement: String
        let shouldBeep: Bool
    }

    /// Writes only meaningful diagnostic payloads. An empty diary leaves the
    /// user's existing clipboard untouched. A failed write restores every
    /// pasteboard item that existed before the attempted replacement.
    @discardableResult
    static func write(
        _ payload: String,
        to pasteboard: NSPasteboard = .general,
        commit: (String, NSPasteboard) -> Bool = { payload, pasteboard in
            pasteboard.setString(payload, forType: .string)
        }
    ) -> Outcome {
        guard !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .empty
        }

        let priorItems = snapshotItems(from: pasteboard)
        pasteboard.clearContents()
        guard commit(payload, pasteboard) else {
            pasteboard.clearContents()
            if !priorItems.isEmpty {
                pasteboard.writeObjects(priorItems)
            }
            return .failed
        }
        return .copied
    }

    static func feedback(for outcome: Outcome) -> Feedback {
        switch outcome {
        case .copied:
            return Feedback(
                announcement: "Redacted diagnostics copied for your bug report.",
                shouldBeep: false
            )
        case .empty:
            return Feedback(
                announcement: "No diagnostics are available to copy yet.",
                shouldBeep: true
            )
        case .failed:
            return Feedback(
                announcement: "Could not copy redacted diagnostics.",
                shouldBeep: true
            )
        }
    }

    private static func snapshotItems(
        from pasteboard: NSPasteboard
    ) -> [NSPasteboardItem] {
        pasteboard.pasteboardItems?.map { source in
            let snapshot = NSPasteboardItem()
            for type in source.types {
                if let data = source.data(forType: type) {
                    snapshot.setData(data, forType: type)
                }
            }
            return snapshot
        } ?? []
    }
}
