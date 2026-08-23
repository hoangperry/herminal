import AppKit
import GhosttyKit
import Testing
@testable import HerminalCore

@Suite("Terminal clipboard authorization policy", .serialized)
@MainActor
struct ClipboardAuthorizationPolicyTests {
    @Test("unsafe paste keeps cancellation as the safe default")
    func unsafePastePresentation() {
        let presentation = TerminalClipboardAuthorizationPresentation(kind: .unsafePaste)

        #expect(presentation.messageText == "Paste potentially unsafe text?")
        #expect(presentation.informativeText.contains("commands may run immediately"))
        #expect(presentation.defaultButtonTitle == "Cancel Paste")
        #expect(presentation.approvalButtonTitle == "Paste Anyway")
        #expect(presentation.approvalHasDestructiveAction)
    }

    @Test("OSC 52 reads explain clipboard disclosure without exposing its contents")
    func remoteReadPresentation() {
        let presentation = TerminalClipboardAuthorizationPresentation(kind: .osc52Read)

        #expect(presentation.messageText == "Allow terminal clipboard read?")
        #expect(presentation.informativeText.contains("read your macOS clipboard"))
        #expect(!presentation.informativeText.contains("clipboard contents:"))
        #expect(presentation.defaultButtonTitle == "Don’t Allow")
        #expect(presentation.approvalButtonTitle == "Allow Once")
        #expect(!presentation.approvalHasDestructiveAction)
    }

    @Test("OSC 52 writes explain replacement and keep denial as the safe default")
    func remoteWritePresentation() {
        let presentation = TerminalClipboardAuthorizationPresentation(kind: .osc52Write)

        #expect(presentation.messageText == "Allow terminal clipboard replacement?")
        #expect(presentation.informativeText.contains("replace your macOS clipboard"))
        #expect(presentation.defaultButtonTitle == "Don’t Allow")
        #expect(presentation.approvalButtonTitle == "Allow Once")
        #expect(presentation.approvalHasDestructiveAction)
    }

    @Test("the first alert button is always safe and unknown responses deny")
    func alertButtonPolicyFailsClosed() {
        let presentation = TerminalClipboardAuthorizationPresentation(kind: .osc52Read)

        #expect(presentation.buttons.map(\.decision) == [.deny, .approve])
        #expect(presentation.decision(forButtonAt: 0) == .deny)
        #expect(presentation.decision(forButtonAt: 1) == .approve)
        #expect(presentation.decision(forButtonAt: -1) == .deny)
        #expect(presentation.decision(forButtonAt: 99) == .deny)
    }

    @Test("authorization gate rejects bursts until the active prompt releases")
    func authorizationGateRejectsPromptBursts() {
        let gate = ClipboardAuthorizationGate()

        #expect(gate.reserve())
        #expect(!gate.reserve())
        gate.release()
        #expect(gate.reserve())
        gate.release()
    }

    @Test("only writes marked for confirmation interrupt normal terminal copies")
    func writeConfirmationPolicy() {
        #expect(!TerminalClipboardAuthorizationPolicy.requiresWriteAuthorization(confirm: false))
        #expect(TerminalClipboardAuthorizationPolicy.requiresWriteAuthorization(confirm: true))
    }

    @Test("request mapping covers only the known trust-boundary prompts")
    func requestMapping() {
        #expect(
            TerminalClipboardAuthorizationPolicy.authorizationKind(
                for: GHOSTTY_CLIPBOARD_REQUEST_PASTE
            ) == .unsafePaste
        )
        #expect(
            TerminalClipboardAuthorizationPolicy.authorizationKind(
                for: GHOSTTY_CLIPBOARD_REQUEST_OSC_52_READ
            ) == .osc52Read
        )
        #expect(
            TerminalClipboardAuthorizationPolicy.authorizationKind(
                for: GHOSTTY_CLIPBOARD_REQUEST_OSC_52_WRITE
            ) == .osc52Write
        )
    }

    @Test("invalid UTF-8 clipboard payloads fail closed")
    func invalidUTF8Payload() {
        let invalid: [Int8] = [0x66, -128, 0]

        invalid.withUnsafeBufferPointer { buffer in
            #expect(
                TerminalClipboardAuthorizationPolicy.decodedPayload(
                    from: buffer.baseAddress
                ) == nil
            )
        }
    }

    @Test("denial completes retained libghostty requests with an empty payload")
    func denialCompletionPayload() {
        let original = "printf 'sensitive payload'\n"

        #expect(
            TerminalClipboardAuthorizationPolicy.completionPayload(
                original,
                approved: false
            ).isEmpty
        )
        #expect(
            TerminalClipboardAuthorizationPolicy.completionPayload(
                original,
                approved: true
            ) == original
        )
    }

    @Test("approved clipboard writes replace the previous string")
    func approvedWriteReplacesClipboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.setString("old clipboard", forType: .string)

        let succeeded = replaceStandardClipboard(
            with: "approved payload",
            pasteboard: pasteboard
        )

        #expect(succeeded)
        #expect(pasteboard.string(forType: .string) == "approved payload")
    }

    @Test("failed clipboard writes restore every previous pasteboard item")
    func failedWriteRestoresClipboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        let previous = NSPasteboardItem()
        previous.setString("sensitive prior value", forType: .string)
        previous.setData(Data([0x01, 0x02]), forType: .init("dev.herminal.test"))
        pasteboard.writeObjects([previous])

        let succeeded = replaceStandardClipboard(
            with: "replacement",
            pasteboard: pasteboard,
            commit: { _, _ in false }
        )

        #expect(!succeeded)
        #expect(pasteboard.string(forType: .string) == "sensitive prior value")
        #expect(
            pasteboard.data(forType: .init("dev.herminal.test"))
                == Data([0x01, 0x02])
        )
    }

    @Test("Herminal baseline source pins OSC 52 reads and writes to ask")
    func baselineClipboardWritePolicy() throws {
        let source = try GhosttyBaselineConfig.source()

        #expect(source.contains("clipboard-read = ask"))
        #expect(source.contains("clipboard-write = ask"))
        #expect(!source.contains("clipboard-read = allow"))
        #expect(!source.contains("clipboard-write = allow"))
    }

    @Test("Herminal baseline resolves both effective clipboard policies to ask")
    func baselineEffectiveClipboardPolicy() throws {
        #expect(
            ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv)
                == GHOSTTY_SUCCESS
        )
        let config = try #require(ghostty_config_new())
        defer { ghostty_config_free(config) }

        #expect(GhosttyBaselineConfig.load(into: config))
        #expect(GhosttyBaselineConfig.clipboardReadAccess(in: config) == "ask")
        #expect(GhosttyBaselineConfig.clipboardWriteAccess(in: config) == "ask")
    }
}
