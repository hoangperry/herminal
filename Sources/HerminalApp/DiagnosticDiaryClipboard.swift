import AppKit

enum SupportIssueOpenOutcome: Equatable {
    case opened
    case failed
}

struct SupportIssueOpenFailureAlert: Equatable {
    let messageText: String
    let informativeText: String
    let copyButtonTitle: String
    let cancelButtonTitle: String
}

enum SupportIssueReporter {
    static let bugReportURL = URL(
        string: "https://github.com/hoangperry/herminal/issues/new?template=bug_report.md"
    )!

    static let openFailureAlert = SupportIssueOpenFailureAlert(
        messageText: "Couldn’t Open the Bug Report",
        informativeText:
            "Visit github.com/hoangperry/herminal/issues/new in your browser. "
            + "Before filing, choose Help > Copy Redacted Diagnostics for Bug Report. "
            + "Review the copied text before pasting it.",
        copyButtonTitle: "Copy Bug Report URL",
        cancelButtonTitle: "Close"
    )

    static func openBugReport(
        using opener: (URL) -> Bool
    ) -> SupportIssueOpenOutcome {
        opener(bugReportURL) ? .opened : .failed
    }

    @MainActor
    static func copyBugReportURL(
        to pasteboard: NSPasteboard = .general
    ) -> DiagnosticDiaryClipboard.Outcome {
        DiagnosticDiaryClipboard.write(
            bugReportURL.absoluteString,
            to: pasteboard
        )
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
