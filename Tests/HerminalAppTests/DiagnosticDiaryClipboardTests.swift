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
