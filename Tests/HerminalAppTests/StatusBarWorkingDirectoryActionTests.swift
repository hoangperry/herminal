import AppKit
import Foundation
import Testing

@testable import HerminalApp

@Suite("Status bar working directory actions", .serialized)
@MainActor
struct StatusBarWorkingDirectoryActionTests {
    @Test("cwd menu uses the dense macOS interactive target")
    func compactInteractiveTarget() {
        #expect(
            StatusBarView.height
                == HerminalDesign.Geometry.compactInteractiveControlSize
        )
    }

    @Test("unavailable path disables both actions")
    func unavailablePathDisablesBothActions() {
        let availability = StatusBarWorkingDirectoryActions.availability(for: nil)

        #expect(!availability.canCopy)
        #expect(!availability.canReveal)
    }

    @Test("untrusted cwd payloads stay unavailable and never touch the clipboard")
    func untrustedPayloadsStayUnavailable() {
        let payloads = [
            "file:///tmp/herminal",
            "/tmp/herminal\nopen -a Calculator"
        ]

        for payload in payloads {
            let pasteboard = NSPasteboard.withUniqueName()
            pasteboard.setString("keep me", forType: .string)

            let availability = StatusBarWorkingDirectoryActions.availability(for: payload)
            let copyOutcome = StatusBarWorkingDirectoryActions.copy(payload, to: pasteboard)
            let revealOutcome = StatusBarWorkingDirectoryActions.reveal(
                payload,
                directoryExists: { _ in
                    Issue.record("invalid cwd payloads must never hit directory validation")
                    return true
                },
                revealInFinder: { _ in
                    Issue.record("invalid cwd payloads must never reach Finder")
                    return true
                }
            )

            #expect(!availability.canCopy)
            #expect(!availability.canReveal)
            #expect(copyOutcome == .unavailable)
            #expect(revealOutcome == .unavailable)
            #expect(pasteboard.string(forType: .string) == "keep me")
        }
    }

    @Test("copy writes the full working directory string")
    func copyWritesFullWorkingDirectoryString() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.setString("old clipboard", forType: .string)
        let fullPath = "/Users/tester/pet-project/herminal"

        let outcome = StatusBarWorkingDirectoryActions.copy(
            fullPath,
            to: pasteboard
        )

        #expect(outcome == .copied)
        #expect(pasteboard.string(forType: .string) == fullPath)
    }

    @Test("copy restores the previous clipboard when the write fails")
    func copyRestoresClipboardOnFailure() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.setString("keep me", forType: .string)

        let outcome = StatusBarWorkingDirectoryActions.copy(
            "/Users/tester/full/path",
            to: pasteboard,
            commit: { _, _ in false }
        )

        #expect(outcome == .failed)
        #expect(pasteboard.string(forType: .string) == "keep me")
    }

    @Test("reveal only accepts an existing directory")
    func revealOnlyAcceptsExistingDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var revealedURL: URL?
        let revealed = StatusBarWorkingDirectoryActions.reveal(
            root.path,
            directoryExists: { url in
                var isDirectory = ObjCBool(false)
                let exists = FileManager.default.fileExists(
                    atPath: url.path,
                    isDirectory: &isDirectory
                )
                return exists && isDirectory.boolValue
            },
            revealInFinder: { url in
                revealedURL = url
                return true
            }
        )

        let missing = StatusBarWorkingDirectoryActions.reveal(
            root.appendingPathComponent("missing", isDirectory: true).path,
            directoryExists: { _ in false },
            revealInFinder: { _ in
                Issue.record("missing directories must never be revealed")
                return true
            }
        )

        #expect(revealed == .revealed)
        #expect(revealedURL?.path == root.path)
        #expect(missing == .failed)
    }

    @Test("feedback stays concise and distinct across outcomes")
    func feedbackStaysConciseAndDistinctAcrossOutcomes() {
        #expect(
            StatusBarWorkingDirectoryActions.feedback(for: .copied)
                == .init(
                    label: "Copied",
                    announcement: "Working directory copied.",
                    shouldBeep: false
                )
        )
        #expect(
            StatusBarWorkingDirectoryActions.feedback(for: .revealed)
                == .init(
                    label: "Revealed",
                    announcement: "Working directory revealed in Finder.",
                    shouldBeep: false
                )
        )
        #expect(
            StatusBarWorkingDirectoryActions.feedback(for: .unavailable)
                == .init(
                    label: "Unavailable",
                    announcement: "No working directory is available yet.",
                    shouldBeep: true
                )
        )
        #expect(
            StatusBarWorkingDirectoryActions.feedback(for: .failed)
                == .init(
                    label: "Failed",
                    announcement: "Working directory action failed.",
                    shouldBeep: true
                )
        )
    }
}
