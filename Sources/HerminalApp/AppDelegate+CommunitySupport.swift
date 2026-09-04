import AppKit

extension AppDelegate {
    /// Copies only Diary's redacted export. The raw on-disk diary never
    /// reaches the pasteboard through this user-facing support action.
    @objc func copyRedactedDiary(_ sender: Any?) {
        let payload = Diary.shared.exportRedacted(maxLines: 200)
        let outcome = DiagnosticDiaryClipboard.write(payload)
        let feedback = DiagnosticDiaryClipboard.feedback(for: outcome)
        if feedback.shouldBeep {
            NSSound.beep()
        }
        if outcome == .copied {
            Diary.shared.log("copied redacted diagnostics", category: "support")
        }
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: feedback.announcement,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }

    /// Opens the official bug-report template on explicit user request.
    /// Diagnostics remain local and are copied only through the separate,
    /// privacy-redacted Help action above.
    @objc func reportProblem(_ sender: Any?) {
        let outcome = SupportIssueReporter.openBugReport { destination in
            NSWorkspace.shared.open(destination)
        }
        handleSupportLinkOpenResult(
            outcome,
            topic: "bug report",
            logTarget: "bug report form",
            failureAlert: SupportIssueReporter.openFailureAlert,
            copyURL: { SupportIssueReporter.copyBugReportURL() }
        )
    }

    /// Opens GitHub's private vulnerability-reporting flow. Security details
    /// must never be routed through the public bug-report action.
    @objc func reportSecurityIssue(_ sender: Any?) {
        let outcome = SupportIssueReporter.openSecurityReport { destination in
            NSWorkspace.shared.open(destination)
        }
        handleSupportLinkOpenResult(
            outcome,
            topic: "private security report",
            logTarget: "private security report",
            failureAlert: SupportIssueReporter.securityReportOpenFailureAlert,
            copyURL: { SupportIssueReporter.copySecurityReportURL() }
        )
    }

    /// Opens the official privacy-safe beta workflow form. Herminal sends
    /// nothing automatically; the tester reviews and submits the form in
    /// their browser.
    @objc func shareBetaFeedback(_ sender: Any?) {
        let outcome = SupportIssueReporter.openBetaFeedback { destination in
            NSWorkspace.shared.open(destination)
        }
        handleSupportLinkOpenResult(
            outcome,
            topic: "beta feedback",
            logTarget: "beta feedback form",
            failureAlert: SupportIssueReporter.betaFeedbackOpenFailureAlert,
            copyURL: { SupportIssueReporter.copyBetaFeedbackURL() }
        )
    }

    /// Opens the official GitHub feature request template. Herminal sends
    /// nothing automatically; the contributor reviews and submits the form
    /// in their browser.
    @objc func suggestFeature(_ sender: Any?) {
        let outcome = SupportIssueReporter.openFeatureRequest { destination in
            NSWorkspace.shared.open(destination)
        }
        handleSupportLinkOpenResult(
            outcome,
            topic: "feature request",
            logTarget: "feature request form",
            failureAlert: SupportIssueReporter.featureRequestOpenFailureAlert,
            copyURL: { SupportIssueReporter.copyFeatureRequestURL() }
        )
    }

    /// Opens the contributor guide before a community member invests time in
    /// a pull request, keeping scope and verification requirements discoverable.
    @objc func openContributorGuide(_ sender: Any?) {
        let outcome = SupportIssueReporter.openContributorGuide { destination in
            NSWorkspace.shared.open(destination)
        }
        handleSupportLinkOpenResult(
            outcome,
            topic: "contributor guide",
            logTarget: "contributor guide",
            failureAlert: SupportIssueReporter.contributorGuideOpenFailureAlert,
            copyURL: { SupportIssueReporter.copyContributorGuideURL() }
        )
    }

    /// Opens the maintained troubleshooting guide so users can recover from
    /// common failures before collecting diagnostics or filing an issue.
    @objc func openTroubleshootingGuide(_ sender: Any?) {
        let outcome = SupportIssueReporter.openTroubleshootingGuide { destination in
            NSWorkspace.shared.open(destination)
        }
        handleSupportLinkOpenResult(
            outcome,
            topic: "troubleshooting guide",
            logTarget: "troubleshooting guide",
            failureAlert: SupportIssueReporter.troubleshootingGuideOpenFailureAlert,
            copyURL: { SupportIssueReporter.copyTroubleshootingGuideURL() }
        )
    }

    private func handleSupportLinkOpenResult(
        _ outcome: SupportIssueOpenOutcome,
        topic: String,
        logTarget: String,
        failureAlert: SupportIssueOpenFailureAlert,
        copyURL: () -> DiagnosticDiaryClipboard.Outcome
    ) {
        guard outcome == .failed else {
            Diary.shared.log("opened \(logTarget)", category: "support")
            return
        }

        Diary.shared.log("could not open \(logTarget)", category: "support")
        NSSound.beep()
        let announcementTopic = topic.prefix(1).uppercased() + topic.dropFirst()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = failureAlert.messageText
        alert.informativeText = failureAlert.informativeText
        alert.addButton(withTitle: failureAlert.copyButtonTitle)
        alert.addButton(withTitle: failureAlert.cancelButtonTitle)
        if let manualRecoveryURL = failureAlert.manualRecoveryURL {
            alert.accessoryView = Self.makeSupportIssueRecoveryURLField(
                for: manualRecoveryURL,
                accessibilityLabel: "\(announcementTopic) URL"
            )
        }
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let copyOutcome = copyURL()
        let announcement: String
        switch copyOutcome {
        case .copied:
            Diary.shared.log("copied \(topic) URL", category: "support")
            announcement = "\(announcementTopic) URL copied."
        case .empty, .failed:
            NSSound.beep()
            announcement = "Could not copy the \(topic) URL."
        }
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: announcement,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }

    static func makeSupportIssueRecoveryURLField(
        for url: URL,
        accessibilityLabel: String
    ) -> NSTextField {
        let field = NSTextField(string: url.absoluteString)
        field.frame = NSRect(x: 0, y: 0, width: 420, height: 22)
        field.isEditable = false
        field.isSelectable = true
        field.lineBreakMode = .byTruncatingMiddle
        field.toolTip = url.absoluteString
        field.setAccessibilityLabel(accessibilityLabel)
        field.setAccessibilityHelp(
            "Select and copy this address if the Copy URL button does not work."
        )
        return field
    }
}
