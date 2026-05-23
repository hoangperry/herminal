// HerminalSurfaceView — an NSView that hosts one libghostty terminal surface.
// libghostty owns rendering: given the NSView pointer it attaches its own
// Metal layer and draws the terminal grid. This view bridges AppKit input
// (keyboard + IME) and lifecycle (size/scale/focus) into libghostty.

import AppKit
import GhosttyKit

final class HerminalSurfaceView: NSView {
    private let app: ghostty_app_t
    // nonisolated(unsafe): a C handle freed once in deinit (NSView deinit is nonisolated).
    private nonisolated(unsafe) var surface: ghostty_surface_t?

    /// IME composition (preedit) text — underlined text shown while composing,
    /// e.g. Vietnamese Telex "tieesng" before it commits to "tiếng".
    private var markedText = NSMutableAttributedString()

    /// Set to a non-nil array during `keyDown` so `insertText` accumulates the
    /// IME's committed text instead of sending it straight to the PTY.
    private var keyTextAccumulator: [String]?

    init(app: ghostty_app_t) {
        self.app = app
        // Non-zero frame: libghostty's renderer needs non-zero layer bounds
        // (see Ghostty's SurfaceView_AppKit init comment).
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }

    required init?(coder: NSCoder) {
        fatalError("HerminalSurfaceView does not support NSCoder")
    }

    // MARK: - Surface lifecycle

    // Surface creation waits for a window so a real backing scale factor exists.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, surface == nil else { return }
        createSurface()
    }

    private func createSurface() {
        var config = ghostty_surface_config_new()
        let viewPointer = Unmanaged.passUnretained(self).toOpaque()
        config.userdata = viewPointer
        config.platform_tag = GHOSTTY_PLATFORM_MACOS
        config.platform = ghostty_platform_u(
            macos: ghostty_platform_macos_s(nsview: viewPointer)
        )
        let scaleFactor = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2.0
        config.scale_factor = Double(scaleFactor)
        config.font_size = 0 // 0 = inherit from config

        guard let surface = ghostty_surface_new(app, &config) else {
            NSLog("herminal: ghostty_surface_new failed")
            return
        }
        self.surface = surface
        ghostty_surface_set_focus(surface, true)
        syncSize()
    }

    private func syncSize() {
        guard let surface else { return }
        let backing = convertToBacking(bounds.size)
        ghostty_surface_set_size(
            surface,
            UInt32(max(backing.width, 1)),
            UInt32(max(backing.height, 1))
        )
        let scale = Double(window?.backingScaleFactor ?? 2.0)
        ghostty_surface_set_content_scale(surface, scale, scale)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        syncSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        syncSize()
    }

    // MARK: - Focus

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        if let surface { ghostty_surface_set_focus(surface, true) }
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        if let surface { ghostty_surface_set_focus(surface, false) }
        return super.resignFirstResponder()
    }

    /// Injects raw text into the surface — bypasses key events / IME entirely.
    /// Used by the GUI test harness so input does not depend on the system
    /// keyboard or input source (osascript / Telex composition would corrupt it).
    func injectText(_ text: String) {
        guard let surface else { return }
        let count = text.utf8.count
        guard count > 0 else { return }
        text.withCString { ptr in
            ghostty_surface_text(surface, ptr, UInt(count))
        }
    }

    // MARK: - Keyboard input

    override func keyDown(with event: NSEvent) {
        guard surface != nil else { return }
        let action: ghostty_input_action_e =
            event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS

        let hadMarkedText = markedText.length > 0

        // Route the event through the input context so the IME can compose.
        // insertText / setMarkedText callbacks fire synchronously within this call.
        keyTextAccumulator = []
        interpretKeyEvents([event])
        let accumulated = keyTextAccumulator
        keyTextAccumulator = nil

        // Push the (possibly updated) composition state to libghostty.
        syncPreedit()

        if let accumulated, !accumulated.isEmpty {
            // The IME committed one or more strings (e.g. a composed "ế").
            for text in accumulated {
                sendKey(event, action: action, text: text, composing: false)
            }
        } else {
            // Plain key event with no committed text.
            sendKey(
                event,
                action: action,
                text: Self.printableText(for: event),
                composing: markedText.length > 0 || hadMarkedText
            )
        }
    }

    override func keyUp(with event: NSEvent) {
        sendKey(event, action: GHOSTTY_ACTION_RELEASE, text: nil, composing: false)
    }

    /// Translates an NSEvent key event into a libghostty key event.
    /// libghostty accepts the raw macOS keyCode directly and encodes control
    /// characters itself, so printable text is attached only for codepoints >= 0x20.
    private func sendKey(
        _ event: NSEvent,
        action: ghostty_input_action_e,
        text: String?,
        composing: Bool
    ) {
        guard let surface else { return }

        var keyEvent = ghostty_input_key_s()
        keyEvent.action = action
        keyEvent.keycode = UInt32(event.keyCode)
        keyEvent.mods = Self.ghosttyMods(event.modifierFlags)
        keyEvent.consumed_mods = Self.ghosttyMods(
            event.modifierFlags.subtracting([.control, .command]))
        keyEvent.composing = composing
        keyEvent.unshifted_codepoint = 0
        if let bare = event.characters(byApplyingModifiers: []),
           let scalar = bare.unicodeScalars.first {
            keyEvent.unshifted_codepoint = scalar.value
        }

        if let text, let firstByte = text.utf8.first, firstByte >= 0x20 {
            _ = text.withCString { ptr in
                keyEvent.text = ptr
                return ghostty_surface_key(surface, keyEvent)
            }
        } else {
            _ = ghostty_surface_key(surface, keyEvent)
        }
    }

    /// Overridden to swallow unhandled selectors so AppKit does not emit NSBeep.
    /// The terminal encodes every key itself via `keyDown`.
    override func doCommand(by selector: Selector) {}

    /// Pushes the current IME composition text to libghostty as preedit.
    private func syncPreedit() {
        guard let surface else { return }
        if markedText.length > 0 {
            let str = markedText.string
            let byteCount = str.utf8CString.count
            if byteCount > 1 {
                str.withCString { ptr in
                    ghostty_surface_preedit(surface, ptr, UInt(byteCount - 1))
                }
            }
        } else {
            ghostty_surface_preedit(surface, nil, 0)
        }
    }

    private static func ghosttyMods(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var mods: UInt32 = GHOSTTY_MODS_NONE.rawValue
        if flags.contains(.shift) { mods |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { mods |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { mods |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { mods |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { mods |= GHOSTTY_MODS_CAPS.rawValue }
        return ghostty_input_mods_e(mods)
    }

    /// Printable text for a key event. Control characters are dropped (libghostty
    /// encodes those from keycode + mods); PUA function-key codepoints are dropped too.
    private static func printableText(for event: NSEvent) -> String? {
        guard let characters = event.characters else { return nil }
        if characters.count == 1, let scalar = characters.unicodeScalars.first {
            if scalar.value < 0x20 {
                return event.characters(
                    byApplyingModifiers: event.modifierFlags.subtracting(.control))
            }
            if scalar.value >= 0xF700 && scalar.value <= 0xF8FF {
                return nil
            }
        }
        return characters
    }

    deinit {
        if let surface {
            ghostty_surface_free(surface)
        }
    }
}

// MARK: - NSTextInputClient (IME / Vietnamese Telex & VNI)

extension HerminalSurfaceView: @MainActor NSTextInputClient {
    func hasMarkedText() -> Bool {
        markedText.length > 0
    }

    func markedRange() -> NSRange {
        markedText.length > 0
            ? NSRange(location: 0, length: markedText.length)
            : NSRange()
    }

    func selectedRange() -> NSRange {
        NSRange()
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    func attributedSubstring(
        forProposedRange range: NSRange,
        actualRange: NSRangePointer?
    ) -> NSAttributedString? {
        nil
    }

    func characterIndex(for point: NSPoint) -> Int {
        0
    }

    /// Composition update — the IME reports the in-progress (underlined) text.
    func setMarkedText(
        _ string: Any,
        selectedRange: NSRange,
        replacementRange: NSRange
    ) {
        switch string {
        case let value as NSAttributedString:
            markedText = NSMutableAttributedString(attributedString: value)
        case let value as String:
            markedText = NSMutableAttributedString(string: value)
        default:
            return
        }
        // Outside a keyDown (e.g. layout change while composing) sync immediately.
        if keyTextAccumulator == nil {
            syncPreedit()
        }
    }

    func unmarkText() {
        guard markedText.length > 0 else { return }
        markedText.mutableString.setString("")
        syncPreedit()
    }

    /// Committed text from the IME (or a plain key). Sent to the PTY.
    func insertText(_ string: Any, replacementRange: NSRange) {
        let chars: String
        switch string {
        case let value as NSAttributedString:
            chars = value.string
        case let value as String:
            chars = value
        default:
            return
        }

        // Committing text ends any composition.
        unmarkText()

        // Inside a keyDown: accumulate so keyDown can emit it as a key event.
        if keyTextAccumulator != nil {
            keyTextAccumulator?.append(chars)
            return
        }

        // Outside a keyDown: send straight to libghostty.
        guard let surface else { return }
        let byteCount = chars.utf8CString.count
        guard byteCount > 1 else { return }
        chars.withCString { ptr in
            ghostty_surface_text(surface, ptr, UInt(byteCount - 1))
        }
    }

    /// Tells the IME where to place its candidate window (screen coordinates).
    func firstRect(
        forCharacterRange range: NSRange,
        actualRange: NSRangePointer?
    ) -> NSRect {
        guard let surface else {
            return NSRect(origin: frame.origin, size: .zero)
        }

        var x = 0.0, y = 0.0, width = 0.0, height = 0.0
        ghostty_surface_ime_point(surface, &x, &y, &width, &height)

        // libghostty uses a top-left origin; AppKit views use bottom-left.
        let viewRect = NSRect(
            x: x,
            y: frame.size.height - y,
            width: width,
            height: max(height, 1)
        )
        let windowRect = convert(viewRect, to: nil)
        guard let window else { return windowRect }
        return window.convertToScreen(windowRect)
    }
}
