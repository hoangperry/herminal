import AppKit
import Testing

@testable import HerminalApp

@Suite("Diagnostic diary clipboard", .serialized)
@MainActor
struct DiagnosticDiaryClipboardTests {
    @Test("Help menu exposes the privacy-safe diary copy action")
    func helpMenuExposesCopyAction() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let helpMenu = try #require(
            menu.items.compactMap(\.submenu).first { $0.title == "Help" }
        )
        let item = try #require(helpMenu.items.first {
            $0.title == "Copy Redacted Diagnostics for Bug Report"
        })

        #expect(AppMenu.helpMenu(in: menu) === helpMenu)
        #expect(item.action == NSSelectorFromString("copyRedactedDiary:"))
        #expect(item.toolTip == "Copies the latest 200 privacy-redacted diagnostic entries for a bug report.")
        #expect(
            item.accessibilityHelp()
                == "Copies the latest 200 privacy-redacted diagnostic entries for a bug report."
        )
    }

    @Test("Command palette exposes the privacy-safe diary copy action")
    func commandPaletteExposesCopyAction() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let item = try #require(CommandPaletteCatalog.actions(from: menu).first {
            $0.id == "copy-redacted-diagnostics"
        })

        #expect(item.title == "Copy Redacted Diagnostics for Bug Report")
        #expect(
            item.subtitle
                == "Copy the latest 200 privacy-redacted diagnostic entries for a bug report"
        )
        #expect(item.shortcutDisplay == nil)
        #expect(item.selector == #selector(AppDelegate.copyRedactedDiary(_:)))
        #expect(item.menuPath == "Help")
    }

    @Test("Help and command palette expose the official bug report flow")
    func supportEntryPoints() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let helpMenu = try #require(AppMenu.helpMenu(in: menu))
        let helpItem = try #require(helpMenu.items.first {
            $0.title == "Report a Problem…"
        })
        let copyIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Copy Redacted Diagnostics for Bug Report"
        })
        let reportIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Report a Problem…"
        })

        #expect(helpItem.action == #selector(AppDelegate.reportProblem(_:)))
        #expect(helpItem.isEnabled)
        #expect(copyIndex < reportIndex)
        #expect(
            helpItem.toolTip
                == "Opens the official GitHub bug report form. Copy redacted diagnostics first; herminal never uploads them."
        )
        #expect(
            helpItem.accessibilityHelp()
                == "Opens the official GitHub bug report form. Copy redacted diagnostics first; herminal never uploads them."
        )

        let paletteItem = try #require(
            CommandPaletteCatalog.actions(from: menu).first {
                $0.id == "report-problem"
            }
        )
        #expect(paletteItem.title == "Report a Problem")
        #expect(
            paletteItem.subtitle
                == "Open the official GitHub bug report form; diagnostics stay local until you copy them"
        )
        #expect(paletteItem.selector == #selector(AppDelegate.reportProblem(_:)))
        #expect(paletteItem.menuPath == "Help")
        #expect(
            CommandPaletteView.filteredActions(
                CommandPaletteCatalog.actions(from: menu),
                query: "bug report"
            ).contains { $0.id == "report-problem" }
        )
    }

    @Test("Help and command palette expose privacy-safe beta feedback")
    func betaFeedbackEntryPoints() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let helpMenu = try #require(AppMenu.helpMenu(in: menu))
        let helpItem = try #require(helpMenu.items.first {
            $0.title == "Open Beta Feedback Form…"
        })
        let separatorIndex = try #require(helpMenu.items.firstIndex { $0.isSeparatorItem })
        let copyDiagnosticsIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Copy Redacted Diagnostics for Bug Report"
        })
        let reportIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Report a Problem…"
        })
        let betaIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Open Beta Feedback Form…"
        })

        #expect(helpItem.action == #selector(AppDelegate.shareBetaFeedback(_:)))
        #expect(helpItem.isEnabled)
        #expect(betaIndex < separatorIndex)
        #expect(separatorIndex < copyDiagnosticsIndex)
        #expect(copyDiagnosticsIndex < reportIndex)
        #expect(
            helpItem.toolTip
                == "Opens the GitHub beta feedback form in your browser. Review every field before submitting; herminal never uploads diagnostics."
        )
        #expect(helpItem.accessibilityHelp() == helpItem.toolTip)

        let paletteItem = try #require(
            CommandPaletteCatalog.actions(from: menu).first {
                $0.id == "share-beta-feedback"
            }
        )
        #expect(paletteItem.title == "Open Beta Feedback Form")
        #expect(
            paletteItem.subtitle
                == "Open the GitHub beta workflow form in your browser; herminal never uploads diagnostics"
        )
        #expect(paletteItem.selector == #selector(AppDelegate.shareBetaFeedback(_:)))
        #expect(paletteItem.menuPath == "Help")
        #expect(
            CommandPaletteView.filteredActions(
                CommandPaletteCatalog.actions(from: menu),
                query: "beta workflow"
            ).contains { $0.id == "share-beta-feedback" }
        )
        #expect(
            CommandPaletteView.filteredActions(
                CommandPaletteCatalog.actions(from: menu),
                query: "share beta"
            ).contains { $0.id == "share-beta-feedback" }
        )
    }

    @Test("Help and command palette expose privacy-safe feature requests")
    func featureRequestEntryPoints() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let helpMenu = try #require(AppMenu.helpMenu(in: menu))
        let helpItem = try #require(helpMenu.items.first {
            $0.title == "Suggest a Feature…"
        })
        let betaIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Open Beta Feedback Form…"
        })
        let featureIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Suggest a Feature…"
        })
        let separatorIndex = try #require(helpMenu.items.firstIndex { $0.isSeparatorItem })

        #expect(helpItem.action == #selector(AppDelegate.suggestFeature(_:)))
        #expect(helpItem.isEnabled)
        #expect(betaIndex < featureIndex)
        #expect(featureIndex < separatorIndex)
        #expect(
            helpItem.toolTip
                == "Opens the official GitHub feature request form in your browser. Describe the problem without including private terminal data or credentials."
        )
        #expect(helpItem.accessibilityHelp() == helpItem.toolTip)

        let paletteItem = try #require(
            CommandPaletteCatalog.actions(from: menu).first {
                $0.id == "suggest-feature"
            }
        )
        #expect(paletteItem.title == "Suggest a Feature")
        #expect(
            paletteItem.subtitle
                == "Open the official GitHub feature request form in your browser; herminal uploads nothing"
        )
        #expect(paletteItem.selector == #selector(AppDelegate.suggestFeature(_:)))
        #expect(paletteItem.menuPath == "Help")
        #expect(
            CommandPaletteView.filteredActions(
                CommandPaletteCatalog.actions(from: menu),
                query: "feature request"
            ).contains { $0.id == "suggest-feature" }
        )
    }

    @Test("Help and command palette expose the official contributor guide")
    func contributorGuideEntryPoints() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let helpMenu = try #require(AppMenu.helpMenu(in: menu))
        let helpItem = try #require(helpMenu.items.first {
            $0.title == "Contribute to herminal…"
        })
        let featureIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Suggest a Feature…"
        })
        let contributorIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Contribute to herminal…"
        })
        let separatorIndex = try #require(helpMenu.items.firstIndex { $0.isSeparatorItem })

        #expect(helpItem.action == #selector(AppDelegate.openContributorGuide(_:)))
        #expect(helpItem.isEnabled)
        #expect(featureIndex < contributorIndex)
        #expect(contributorIndex < separatorIndex)
        #expect(
            helpItem.toolTip
                == "Opens the official contributor guide in your browser. Review scope and testing requirements before opening a pull request."
        )
        #expect(helpItem.accessibilityHelp() == helpItem.toolTip)

        let actions = CommandPaletteCatalog.actions(from: menu)
        let paletteItem = try #require(actions.first { $0.id == "contribute" })
        #expect(paletteItem.title == "Contribute to herminal")
        #expect(
            paletteItem.subtitle
                == "Read the contributor guide (CONTRIBUTING.md): scope, setup, tests, and pull request requirements"
        )
        #expect(paletteItem.selector == #selector(AppDelegate.openContributorGuide(_:)))
        #expect(paletteItem.menuPath == "Help")
        for query in ["contributor guide", "contributing", "pull request"] {
            #expect(
                CommandPaletteView.filteredActions(actions, query: query)
                    .contains { $0.id == "contribute" }
            )
        }
    }

    @Test("bug reporting opens the official template exactly once")
    func bugReportDestination() {
        var destinations: [URL] = []

        let outcome = SupportIssueReporter.openBugReport { destination in
            destinations.append(destination)
            return true
        }

        #expect(outcome == .opened)
        #expect(destinations == [SupportIssueReporter.bugReportURL])
        #expect(
            SupportIssueReporter.bugReportURL.absoluteString
                == "https://github.com/hoangperry/herminal/issues/new?template=bug_report.md"
        )
    }

    @Test("bug report browser failures explain the manual recovery path")
    func bugReportFailurePresentation() {
        let outcome = SupportIssueReporter.openBugReport { _ in false }
        let presentation = SupportIssueReporter.openFailureAlert

        #expect(outcome == .failed)
        #expect(presentation.messageText == "Couldn’t Open the Bug Report")
        #expect(presentation.informativeText.contains("github.com/hoangperry/herminal/issues/new"))
        #expect(presentation.informativeText.contains("Copy Redacted Diagnostics"))
        #expect(presentation.copyButtonTitle == "Copy Bug Report URL")
        #expect(presentation.cancelButtonTitle == "Close")
    }

    @Test("bug report failure recovery copies the official URL")
    func bugReportFailureCopiesURL() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.setString("keep me if recovery fails", forType: .string)

        let outcome = SupportIssueReporter.copyBugReportURL(to: pasteboard)

        #expect(outcome == .copied)
        #expect(
            pasteboard.string(forType: .string)
                == SupportIssueReporter.bugReportURL.absoluteString
        )
    }

    @Test("beta feedback opens the official privacy-safe form exactly once")
    func betaFeedbackDestination() {
        var destinations: [URL] = []

        let outcome = SupportIssueReporter.openBetaFeedback { destination in
            destinations.append(destination)
            return true
        }

        #expect(outcome == .opened)
        #expect(destinations == [SupportIssueReporter.betaFeedbackURL])
        #expect(
            SupportIssueReporter.betaFeedbackURL.absoluteString
                == "https://github.com/hoangperry/herminal/issues/new?template=beta_report.yml"
        )
    }

    @Test("feature requests open the official template exactly once")
    func featureRequestDestination() {
        var destinations: [URL] = []

        let outcome = SupportIssueReporter.openFeatureRequest { destination in
            destinations.append(destination)
            return true
        }

        #expect(outcome == .opened)
        #expect(destinations == [SupportIssueReporter.featureRequestURL])
        #expect(
            SupportIssueReporter.featureRequestURL.absoluteString
                == "https://github.com/hoangperry/herminal/issues/new?template=feature_request.md"
        )
    }

    @Test("contributor guide opens the official main-branch document exactly once")
    func contributorGuideDestination() {
        var destinations: [URL] = []

        let outcome = SupportIssueReporter.openContributorGuide { destination in
            destinations.append(destination)
            return true
        }

        #expect(outcome == .opened)
        #expect(destinations == [SupportIssueReporter.contributorGuideURL])
        #expect(
            SupportIssueReporter.contributorGuideURL.absoluteString
                == "https://github.com/hoangperry/herminal/blob/main/CONTRIBUTING.md"
        )
    }

    @Test("beta feedback browser failures keep a copyable privacy-safe recovery")
    func betaFeedbackFailureRecovery() {
        let pasteboard = NSPasteboard.withUniqueName()
        let outcome = SupportIssueReporter.openBetaFeedback { _ in false }
        let presentation = SupportIssueReporter.betaFeedbackOpenFailureAlert

        #expect(outcome == .failed)
        #expect(presentation.messageText == "Couldn’t Open Beta Feedback")
        #expect(
            presentation.informativeText.contains(
                SupportIssueReporter.betaFeedbackURL.absoluteString
            )
        )
        #expect(presentation.informativeText.contains("do not include private terminal data"))
        #expect(presentation.copyButtonTitle == "Copy Beta Feedback URL")
        #expect(presentation.cancelButtonTitle == "Close")

        let copyOutcome = SupportIssueReporter.copyBetaFeedbackURL(to: pasteboard)
        #expect(copyOutcome == .copied)
        #expect(
            pasteboard.string(forType: .string)
                == SupportIssueReporter.betaFeedbackURL.absoluteString
        )
    }

    @Test("feature request failures keep a copyable privacy-safe recovery")
    func featureRequestFailureRecovery() {
        let pasteboard = NSPasteboard.withUniqueName()
        let outcome = SupportIssueReporter.openFeatureRequest { _ in false }
        let presentation = SupportIssueReporter.featureRequestOpenFailureAlert

        #expect(outcome == .failed)
        #expect(presentation.messageText == "Couldn’t Open the Feature Request")
        #expect(
            !presentation.informativeText.contains(
                SupportIssueReporter.featureRequestURL.absoluteString
            )
        )
        #expect(presentation.informativeText.contains("paste it into any browser"))
        #expect(presentation.informativeText.contains("private terminal data or credentials"))
        #expect(presentation.manualRecoveryURL == SupportIssueReporter.featureRequestURL)
        #expect(presentation.copyButtonTitle == "Copy Feature Request URL")
        #expect(presentation.cancelButtonTitle == "Close")

        let manualURLField = AppDelegate.makeSupportIssueRecoveryURLField(
            for: SupportIssueReporter.featureRequestURL,
            accessibilityLabel: "Feature request URL"
        )
        #expect(manualURLField.stringValue == SupportIssueReporter.featureRequestURL.absoluteString)
        #expect(manualURLField.isSelectable)
        #expect(!manualURLField.isEditable)
        #expect(manualURLField.accessibilityLabel() == "Feature request URL")
        #expect(manualURLField.accessibilityHelp()?.contains("Copy URL button") == true)

        let copyOutcome = SupportIssueReporter.copyFeatureRequestURL(to: pasteboard)
        #expect(copyOutcome == .copied)
        #expect(
            pasteboard.string(forType: .string)
                == SupportIssueReporter.featureRequestURL.absoluteString
        )
    }

    @Test("contributor guide failures keep an accessible manual recovery")
    func contributorGuideFailureRecovery() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        let outcome = SupportIssueReporter.openContributorGuide { _ in false }
        let presentation = SupportIssueReporter.contributorGuideOpenFailureAlert
        let manualRecoveryURL = try #require(presentation.manualRecoveryURL)

        #expect(outcome == .failed)
        #expect(presentation.messageText == "Couldn’t Open the Contributor Guide")
        #expect(!presentation.informativeText.contains(manualRecoveryURL.absoluteString))
        #expect(presentation.informativeText.contains("paste it into any browser"))
        #expect(presentation.manualRecoveryURL == SupportIssueReporter.contributorGuideURL)
        #expect(presentation.copyButtonTitle == "Copy Contributor Guide URL")
        #expect(presentation.cancelButtonTitle == "Close")

        let manualURLField = AppDelegate.makeSupportIssueRecoveryURLField(
            for: SupportIssueReporter.contributorGuideURL,
            accessibilityLabel: "Contributor guide URL"
        )
        #expect(manualURLField.stringValue == manualRecoveryURL.absoluteString)
        #expect(manualURLField.isSelectable)
        #expect(!manualURLField.isEditable)
        #expect(manualURLField.accessibilityLabel() == "Contributor guide URL")

        let copyOutcome = SupportIssueReporter.copyContributorGuideURL(to: pasteboard)
        #expect(copyOutcome == .copied)
        #expect(pasteboard.string(forType: .string) == manualRecoveryURL.absoluteString)
    }

    @Test("non-empty redacted diagnostics replace the clipboard")
    func nonEmptyPayloadCopies() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.setString("old clipboard", forType: .string)

        let outcome = DiagnosticDiaryClipboard.write(
            "[test] /Users/<redacted>/project",
            to: pasteboard
        )

        #expect(outcome == .copied)
        #expect(
            pasteboard.string(forType: .string)
                == "[test] /Users/<redacted>/project"
        )
    }

    @Test("an empty diary does not destroy existing clipboard contents")
    func emptyPayloadPreservesClipboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.setString("keep me", forType: .string)

        let outcome = DiagnosticDiaryClipboard.write(" \n\t ", to: pasteboard)

        #expect(outcome == .empty)
        #expect(pasteboard.string(forType: .string) == "keep me")
    }

    @Test("a failed write restores existing clipboard contents")
    func failedWriteRestoresClipboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString("sensitive prior value", forType: .string)

        let outcome = DiagnosticDiaryClipboard.write(
            "new diagnostics",
            to: pasteboard,
            commit: { _, _ in false }
        )

        #expect(outcome == .failed)
        #expect(
            pasteboard.string(forType: .string) == "sensitive prior value"
        )
    }

    @Test("copy outcomes expose distinct assistive feedback")
    func copyOutcomeFeedback() {
        #expect(
            DiagnosticDiaryClipboard.feedback(for: .copied).announcement
                == "Redacted diagnostics copied for your bug report."
        )
        #expect(
            DiagnosticDiaryClipboard.feedback(for: .empty).announcement
                == "No diagnostics are available to copy yet."
        )
        #expect(
            DiagnosticDiaryClipboard.feedback(for: .failed).announcement
                == "Could not copy redacted diagnostics."
        )
        #expect(!DiagnosticDiaryClipboard.feedback(for: .copied).shouldBeep)
        #expect(DiagnosticDiaryClipboard.feedback(for: .empty).shouldBeep)
        #expect(DiagnosticDiaryClipboard.feedback(for: .failed).shouldBeep)
    }
}
