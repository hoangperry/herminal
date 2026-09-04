import AppKit
import Testing

@testable import HerminalApp

@Suite("Support documentation", .serialized)
@MainActor
struct SupportDocumentationTests {
    @Test("Help and command palette expose the troubleshooting guide")
    func troubleshootingEntryPoints() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let helpMenu = try #require(AppMenu.helpMenu(in: menu))
        let helpItem = try #require(helpMenu.items.first {
            $0.title == "Troubleshooting Guide…"
        })
        let shortcutsIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Keyboard Shortcuts…"
        })
        let troubleshootingIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Troubleshooting Guide…"
        })
        let betaIndex = try #require(helpMenu.items.firstIndex {
            $0.title == "Open Beta Feedback Form…"
        })

        #expect(helpItem.action == #selector(AppDelegate.openTroubleshootingGuide(_:)))
        #expect(helpItem.isEnabled)
        #expect(shortcutsIndex < troubleshootingIndex)
        #expect(troubleshootingIndex < betaIndex)
        #expect(
            helpItem.toolTip
                == "Opens self-service fixes for crashes, input methods, agents, SSH, and startup problems."
        )
        #expect(helpItem.accessibilityHelp() == helpItem.toolTip)

        let actions = CommandPaletteCatalog.actions(from: menu)
        let paletteItem = try #require(actions.first {
            $0.id == "troubleshooting-guide"
        })
        #expect(paletteItem.title == "Troubleshooting Guide")
        #expect(
            paletteItem.subtitle
                == "Find self-service fixes for crashes, IME, agents, SSH, and startup problems"
        )
        #expect(paletteItem.selector == #selector(AppDelegate.openTroubleshootingGuide(_:)))
        #expect(paletteItem.menuPath == "Help")
        for query in ["troubleshoot", "crash", "IME", "SSH"] {
            #expect(
                CommandPaletteView.filteredActions(actions, query: query)
                    .contains { $0.id == "troubleshooting-guide" }
            )
        }
    }

    @Test("troubleshooting opens the official main-branch guide exactly once")
    func troubleshootingDestination() {
        var destinations: [URL] = []

        let outcome = SupportIssueReporter.openTroubleshootingGuide { destination in
            destinations.append(destination)
            return true
        }

        #expect(outcome == .opened)
        #expect(destinations == [SupportIssueReporter.troubleshootingGuideURL])
        #expect(
            SupportIssueReporter.troubleshootingGuideURL.absoluteString
                == "https://github.com/hoangperry/herminal/blob/main/docs/TROUBLESHOOTING.md"
        )
    }

    @Test("troubleshooting failures keep an accessible manual recovery")
    func troubleshootingFailureRecovery() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        let outcome = SupportIssueReporter.openTroubleshootingGuide { _ in false }
        let presentation = SupportIssueReporter.troubleshootingGuideOpenFailureAlert
        let manualRecoveryURL = try #require(presentation.manualRecoveryURL)

        #expect(outcome == .failed)
        #expect(presentation.messageText == "Couldn’t Open the Troubleshooting Guide")
        #expect(presentation.informativeText.contains("paste it into any browser"))
        #expect(!presentation.informativeText.contains(manualRecoveryURL.absoluteString))
        #expect(presentation.manualRecoveryURL == SupportIssueReporter.troubleshootingGuideURL)
        #expect(presentation.copyButtonTitle == "Copy Troubleshooting URL")
        #expect(presentation.cancelButtonTitle == "Close")

        let manualURLField = AppDelegate.makeSupportIssueRecoveryURLField(
            for: SupportIssueReporter.troubleshootingGuideURL,
            accessibilityLabel: "Troubleshooting guide URL"
        )
        #expect(manualURLField.stringValue == manualRecoveryURL.absoluteString)
        #expect(manualURLField.isSelectable)
        #expect(!manualURLField.isEditable)
        #expect(manualURLField.accessibilityLabel() == "Troubleshooting guide URL")

        let copyOutcome = SupportIssueReporter.copyTroubleshootingGuideURL(to: pasteboard)
        #expect(copyOutcome == .copied)
        #expect(pasteboard.string(forType: .string) == manualRecoveryURL.absoluteString)
    }
}
