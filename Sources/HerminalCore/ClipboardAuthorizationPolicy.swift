import AppKit
import GhosttyKit

/// Trust-boundary requests emitted by libghostty when terminal content wants
/// access to the macOS clipboard or a paste could execute multiple commands.
enum TerminalClipboardAuthorizationKind: Equatable, Sendable {
    case unsafePaste
    case osc52Read
    case osc52Write
}

enum TerminalClipboardAuthorizationDecision: Equatable, Sendable {
    case deny
    case approve
}

struct TerminalClipboardAuthorizationButton: Equatable, Sendable {
    let title: String
    let decision: TerminalClipboardAuthorizationDecision
    let hasDestructiveAction: Bool
}

/// Native-alert copy kept independent of AppKit so the safe default, risk
/// explanation, and one-shot approval wording stay deterministic in tests.
struct TerminalClipboardAuthorizationPresentation: Equatable, Sendable {
    let messageText: String
    let informativeText: String
    let buttons: [TerminalClipboardAuthorizationButton]

    var defaultButtonTitle: String {
        buttons.first(where: { $0.decision == .deny })?.title ?? ""
    }

    var approvalButtonTitle: String {
        buttons.first(where: { $0.decision == .approve })?.title ?? ""
    }

    var approvalHasDestructiveAction: Bool {
        buttons.first(where: { $0.decision == .approve })?
            .hasDestructiveAction ?? false
    }

    init(kind: TerminalClipboardAuthorizationKind) {
        switch kind {
        case .unsafePaste:
            messageText = "Paste potentially unsafe text?"
            informativeText =
                "This paste contains line breaks, so commands may run "
                + "immediately in the active terminal. Continue only if you "
                + "trust the copied text."
            buttons = [
                .init(title: "Cancel Paste", decision: .deny, hasDestructiveAction: false),
                .init(title: "Paste Anyway", decision: .approve, hasDestructiveAction: true),
            ]
        case .osc52Read:
            messageText = "Allow terminal clipboard read?"
            informativeText =
                "A process running in this terminal requested to read your "
                + "macOS clipboard using OSC 52. Allow only if you trust the "
                + "current process and any remote host."
            buttons = [
                .init(title: "Don’t Allow", decision: .deny, hasDestructiveAction: false),
                .init(title: "Allow Once", decision: .approve, hasDestructiveAction: false),
            ]
        case .osc52Write:
            messageText = "Allow terminal clipboard replacement?"
            informativeText =
                "A process running in this terminal requested to replace your "
                + "macOS clipboard using OSC 52. Allow only if you trust the "
                + "current process and any remote host."
            buttons = [
                .init(title: "Don’t Allow", decision: .deny, hasDestructiveAction: false),
                .init(title: "Allow Once", decision: .approve, hasDestructiveAction: true),
            ]
        }
    }

    func decision(forButtonAt index: Int) -> TerminalClipboardAuthorizationDecision {
        guard buttons.indices.contains(index) else { return .deny }
        return buttons[index].decision
    }
}

/// Thread-safe single-flight reservation for clipboard trust prompts. The
/// reservation happens before work is queued to MainActor, so a prompt burst
/// is denied immediately instead of replaying as a serial modal loop.
final class ClipboardAuthorizationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isReserved = false

    func reserve() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isReserved else { return false }
        isReserved = true
        return true
    }

    func release() {
        lock.lock()
        isReserved = false
        lock.unlock()
    }
}

enum TerminalClipboardAuthorizationPolicy {
    static func requiresWriteAuthorization(confirm: Bool) -> Bool {
        confirm
    }

    /// Embedded libghostty owns an outstanding request until the host calls
    /// `ghostty_surface_complete_clipboard_request`. Completing a denial with
    /// an empty, confirmed payload safely releases that request without
    /// disclosing clipboard contents or sending dangerous paste text.
    static func completionPayload(
        _ original: String,
        approved: Bool
    ) -> String {
        approved ? original : ""
    }

    static func authorizationKind(
        for request: ghostty_clipboard_request_e
    ) -> TerminalClipboardAuthorizationKind? {
        if request == GHOSTTY_CLIPBOARD_REQUEST_PASTE { return .unsafePaste }
        if request == GHOSTTY_CLIPBOARD_REQUEST_OSC_52_READ { return .osc52Read }
        if request == GHOSTTY_CLIPBOARD_REQUEST_OSC_52_WRITE { return .osc52Write }
        return nil
    }

    static func decodedPayload(
        from pointer: UnsafePointer<CChar>?
    ) -> String? {
        guard let pointer else { return nil }
        return String(validatingCString: pointer)
    }
}

enum GhosttyBaselineConfig {
    enum ResourceError: Error {
        case missing
    }

    private static var url: URL? {
        Bundle.module.url(
            forResource: "herminal-defaults",
            withExtension: "conf"
        )
    }

    static func source() throws -> String {
        guard let url else { throw ResourceError.missing }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Loads Herminal's fail-safe defaults before Ghostty's user files. That
    /// order makes `ask` the product default while preserving explicit user
    /// `allow` and `deny` choices.
    static func load(into config: ghostty_config_t) -> Bool {
        guard let path = url?.path,
              let source = try? source(),
              source.contains("clipboard-read = ask"),
              source.contains("clipboard-write = ask") else {
            return false
        }
        let diagnosticsBefore = ghostty_config_diagnostics_count(config)
        path.withCString { pointer in
            ghostty_config_load_file(config, pointer)
        }
        guard ghostty_config_diagnostics_count(config) == diagnosticsBefore else {
            return false
        }
        return clipboardReadAccess(in: config) == "ask"
            && clipboardWriteAccess(in: config) == "ask"
    }

    static func clipboardReadAccess(in config: ghostty_config_t) -> String? {
        access(in: config, key: "clipboard-read")
    }

    static func clipboardWriteAccess(in config: ghostty_config_t) -> String? {
        access(in: config, key: "clipboard-write")
    }

    private static func access(
        in config: ghostty_config_t,
        key: String
    ) -> String? {
        var value: UnsafePointer<CChar>?
        let found = key.withCString { keyPointer in
            ghostty_config_get(
                config,
                &value,
                keyPointer,
                UInt(key.utf8.count)
            )
        }
        guard found, let value else { return nil }
        return String(validatingCString: value)
    }
}

/// Presents the single trust-boundary prompt reserved by
/// `ClipboardAuthorizationGate`.
@MainActor
enum TerminalClipboardAuthorizationAlert {
    static func authorize(
        _ kind: TerminalClipboardAuthorizationKind
    ) -> Bool {
        let presentation = TerminalClipboardAuthorizationPresentation(kind: kind)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = presentation.messageText
        alert.informativeText = presentation.informativeText
        let alertButtons = presentation.buttons.map { button in
            let alertButton = alert.addButton(withTitle: button.title)
            alertButton.hasDestructiveAction = button.hasDestructiveAction
            return alertButton
        }
        guard let safeButtonIndex = presentation.buttons.firstIndex(
            where: { $0.decision == .deny }
        ) else {
            return false
        }
        let safeButton = alertButtons[safeButtonIndex]
        alert.window.initialFirstResponder = safeButton
        let response = alert.runModal()
        let buttonIndex = response.rawValue
            - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        return presentation.decision(forButtonAt: buttonIndex) == .approve
    }
}

/// Owns the copied C payload and retains its surface view while a native
/// authorization alert is pending. `@unchecked Sendable` is constrained to
/// this bridge: all AppKit and libghostty completion work runs on MainActor.
final class PendingClipboardReadAuthorization: @unchecked Sendable {
    private let owner: ClipboardOwner
    private let surface: ghostty_surface_t
    private let state: UnsafeMutableRawPointer
    private let text: String
    private let kind: TerminalClipboardAuthorizationKind
    private let gate: ClipboardAuthorizationGate

    init(
        owner: ClipboardOwner,
        surface: ghostty_surface_t,
        state: UnsafeMutableRawPointer,
        text: String,
        kind: TerminalClipboardAuthorizationKind,
        gate: ClipboardAuthorizationGate
    ) {
        self.owner = owner
        self.surface = surface
        self.state = state
        self.text = text
        self.kind = kind
        self.gate = gate
    }

    @MainActor
    func resolve() {
        defer { gate.release() }
        withExtendedLifetime(owner) {
            let approved = TerminalClipboardAuthorizationAlert.authorize(kind)
            let payload = TerminalClipboardAuthorizationPolicy.completionPayload(
                text,
                approved: approved
            )
            payload.withCString { pointer in
                ghostty_surface_complete_clipboard_request(
                    surface,
                    pointer,
                    state,
                    true
                )
            }
        }
    }
}

final class PendingClipboardWriteAuthorization: @unchecked Sendable {
    private let owner: ClipboardOwner
    private let text: String
    private let gate: ClipboardAuthorizationGate

    init(
        owner: ClipboardOwner,
        text: String,
        gate: ClipboardAuthorizationGate
    ) {
        self.owner = owner
        self.text = text
        self.gate = gate
    }

    @MainActor
    func resolve() {
        defer { gate.release() }
        guard owner.surface != nil else { return }
        guard TerminalClipboardAuthorizationAlert.authorize(.osc52Write) else {
            return
        }
        replaceStandardClipboard(with: text)
    }
}

/// Replaces the standard clipboard transactionally. If AppKit rejects the
/// new string, every previous pasteboard item is restored instead of being
/// destroyed by the required `clearContents()` call.
@discardableResult
@MainActor
func replaceStandardClipboard(
    with text: String,
    pasteboard: NSPasteboard = .general,
    commit: (String, NSPasteboard) -> Bool = { text, pasteboard in
        pasteboard.setString(text, forType: .string)
    }
) -> Bool {
    let previousItems: [NSPasteboardItem] =
        pasteboard.pasteboardItems?.map { source in
            let snapshot = NSPasteboardItem()
            for type in source.types {
                if let data = source.data(forType: type) {
                    snapshot.setData(data, forType: type)
                }
            }
            return snapshot
        } ?? []

    pasteboard.clearContents()
    guard commit(text, pasteboard) else {
        pasteboard.clearContents()
        if !previousItems.isEmpty {
            pasteboard.writeObjects(
                previousItems.map { $0 as NSPasteboardWriting }
            )
        }
        return false
    }
    return true
}
