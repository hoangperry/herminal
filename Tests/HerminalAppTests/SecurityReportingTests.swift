import AppKit
import Testing

@testable import HerminalApp

@Suite("Security reporting", .serialized)
@MainActor
struct SecurityReportingTests {
    @Test("Help and command palette expose private security reporting")
    func securityReportingEntryPoints() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let helpMenu = try #require(AppMenu.helpMenu(in: menu))
        let helpItem = try #require(helpMenu.items.first {
            $0.title == "Report a Security Issue…"
        })
        let problemIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Report a Problem…"
        })
        let securityIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Report a Security Issue…"
        })

        #expect(helpItem.action == #selector(AppDelegate.reportSecurityIssue(_:)))
        #expect(helpItem.isEnabled)
        #expect(securityIndex < problemIndex)
        #expect(
            helpItem.toolTip
                == "Opens GitHub private vulnerability reporting. Never put security details in a public issue."
        )
        #expect(helpItem.accessibilityHelp() == helpItem.toolTip)

        let actions = CommandPaletteCatalog.actions(from: menu)
        let paletteSecurityIndex = try #require(actions.firstIndex {
            $0.id == "report-security-issue"
        })
        let paletteProblemIndex = try #require(actions.firstIndex {
            $0.id == "report-problem"
        })
        let paletteItem = try #require(actions.first {
            $0.id == "report-security-issue"
        })
        #expect(paletteSecurityIndex < paletteProblemIndex)
        #expect(paletteItem.title == "Report a Security Issue")
        #expect(
            paletteItem.subtitle
                == "Open GitHub private vulnerability reporting; never file security details as a public issue"
        )
        #expect(paletteItem.selector == #selector(AppDelegate.reportSecurityIssue(_:)))
        #expect(paletteItem.menuPath == "Help")
        for query in ["security issue", "vulnerability", "private report"] {
            #expect(
                CommandPaletteView.filteredActions(actions, query: query)
                    .contains { $0.id == "report-security-issue" }
            )
        }
    }

    @Test("security reporting opens the official private advisory exactly once")
    func securityReportingDestination() {
        var destinations: [URL] = []

        let outcome = SupportIssueReporter.openSecurityReport { destination in
            destinations.append(destination)
            return true
        }

        #expect(outcome == .opened)
        #expect(destinations == [SupportIssueReporter.securityReportURL])
        #expect(
            SupportIssueReporter.securityReportURL.absoluteString
                == "https://github.com/hoangperry/herminal/security/advisories/new"
        )
    }

    @Test("security reporting failures keep a private accessible recovery")
    func securityReportingFailureRecovery() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        let outcome = SupportIssueReporter.openSecurityReport { _ in false }
        let presentation = SupportIssueReporter.securityReportOpenFailureAlert
        let manualRecoveryURL = try #require(presentation.manualRecoveryURL)
        let secondaryContact = try #require(presentation.secondaryRecoveryContact)

        #expect(outcome == .failed)
        #expect(presentation.messageText == "Couldn’t Open Private Security Reporting")
        #expect(presentation.informativeText.contains("Do not file a public issue"))
        #expect(presentation.informativeText.contains("If GitHub is unavailable"))
        #expect(!presentation.informativeText.contains(manualRecoveryURL.absoluteString))
        #expect(!presentation.informativeText.contains(secondaryContact.value))
        #expect(presentation.manualRecoveryURL == SupportIssueReporter.securityReportURL)
        #expect(secondaryContact.value == SupportIssueReporter.securityReportEmail)
        #expect(secondaryContact.accessibilityLabel == "Private security report email")
        #expect(presentation.copyButtonTitle == "Copy Private Report URL")
        #expect(presentation.cancelButtonTitle == "Close")

        let manualURLField = AppDelegate.makeSupportIssueRecoveryURLField(
            for: SupportIssueReporter.securityReportURL,
            accessibilityLabel: "Private security report URL"
        )
        #expect(manualURLField.stringValue == manualRecoveryURL.absoluteString)
        #expect(manualURLField.isSelectable)
        #expect(!manualURLField.isEditable)
        #expect(manualURLField.accessibilityLabel() == "Private security report URL")

        let emailField = AppDelegate.makeSupportIssueRecoveryContactField(
            for: secondaryContact
        )
        #expect(emailField.stringValue == SupportIssueReporter.securityReportEmail)
        #expect(emailField.isSelectable)
        #expect(!emailField.isEditable)
        #expect(emailField.accessibilityLabel() == "Private security report email")
        #expect(emailField.accessibilityHelp()?.contains("copy this contact") == true)

        let accessoryView = AppDelegate.makeSupportIssueRecoveryAccessoryView(
            for: presentation,
            primaryAccessibilityLabel: "Private security report URL"
        )
        #expect(accessoryView.arrangedSubviews.count == 2)

        let copyOutcome = SupportIssueReporter.copySecurityReportURL(to: pasteboard)
        #expect(copyOutcome == .copied)
        #expect(pasteboard.string(forType: .string) == manualRecoveryURL.absoluteString)
    }
}
