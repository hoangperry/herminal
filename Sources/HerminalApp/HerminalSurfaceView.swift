// HerminalSurfaceView — an NSView that hosts one libghostty terminal surface.
// libghostty owns rendering: given the NSView pointer it attaches its own
// Metal layer and draws the terminal grid. This view's job is lifecycle +
// size/scale/focus plumbing.

import AppKit
import GhosttyKit

final class HerminalSurfaceView: NSView {
    private let app: ghostty_app_t
    // nonisolated(unsafe): a C handle freed once in deinit (NSView deinit is nonisolated).
    private nonisolated(unsafe) var surface: ghostty_surface_t?

    init(app: ghostty_app_t) {
        self.app = app
        // Non-zero frame: libghostty's renderer needs non-zero layer bounds
        // (see Ghostty's SurfaceView_AppKit init comment).
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }

    required init?(coder: NSCoder) {
        fatalError("HerminalSurfaceView does not support NSCoder")
    }

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

    // Terminal surfaces must take keyboard focus.
    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        if let surface { ghostty_surface_set_focus(surface, true) }
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        if let surface { ghostty_surface_set_focus(surface, false) }
        return super.resignFirstResponder()
    }

    // MARK: - Keyboard input

    override func keyDown(with event: NSEvent) {
        let action: ghostty_input_action_e =
            event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS
        sendKey(event, action: action)
    }

    override func keyUp(with event: NSEvent) {
        sendKey(event, action: GHOSTTY_ACTION_RELEASE)
    }

    /// Translates an NSEvent key event into a libghostty key event.
    /// libghostty accepts the raw macOS keyCode directly and encodes control
    /// characters itself, so printable text is attached only for codepoints >= 0x20.
    private func sendKey(_ event: NSEvent, action: ghostty_input_action_e) {
        guard let surface else { return }

        var keyEvent = ghostty_input_key_s()
        keyEvent.action = action
        keyEvent.keycode = UInt32(event.keyCode)
        keyEvent.mods = Self.ghosttyMods(event.modifierFlags)
        keyEvent.consumed_mods = Self.ghosttyMods(
            event.modifierFlags.subtracting([.control, .command]))
        keyEvent.composing = false
        keyEvent.unshifted_codepoint = 0
        if let bare = event.characters(byApplyingModifiers: []),
           let scalar = bare.unicodeScalars.first {
            keyEvent.unshifted_codepoint = scalar.value
        }

        if let text = Self.printableText(for: event),
           let firstByte = text.utf8.first, firstByte >= 0x20 {
            _ = text.withCString { ptr in
                keyEvent.text = ptr
                return ghostty_surface_key(surface, keyEvent)
            }
        } else {
            _ = ghostty_surface_key(surface, keyEvent)
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
