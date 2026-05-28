// GhosttyApp — owns the single libghostty `ghostty_app_t` instance.
// This is the app-level handle: configuration + runtime callbacks + event-loop tick.
// Surfaces (terminal views) are created against the app handle exposed here.

import AppKit
import Foundation
import GhosttyKit
import os

/// Owns the libghostty application instance and its configuration.
///
/// libghostty is single-threaded against AppKit, so this type is main-actor isolated.
@MainActor
public final class GhosttyApp {
    public enum StartupError: Error, Equatable {
        case initFailed(Int32)
        case configFailed
        case appCreationFailed
    }

    /// The libghostty app handle. Pass this to `ghostty_surface_new`.
    /// `nonisolated(unsafe)`: an immutable C pointer, freed once in `deinit`.
    public nonisolated(unsafe) let app: ghostty_app_t

    private nonisolated(unsafe) let config: ghostty_config_t
    private static let logger = Logger(
        subsystem: "com.hoangperry.herminal",
        category: "ghostty-app"
    )

    public init() throws(StartupError) {
        // Global libghostty init — consumes the process argument vector.
        let initResult = ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv)
        guard initResult == GHOSTTY_SUCCESS else {
            GhosttyApp.logger.critical("ghostty_init failed: \(initResult)")
            throw .initFailed(initResult)
        }

        // Configuration — default files only for the Month-1 spike.
        guard let configHandle = ghostty_config_new() else {
            throw .configFailed
        }
        ghostty_config_load_default_files(configHandle)
        ghostty_config_finalize(configHandle)

        // Runtime config wires libghostty back into the host environment.
        // Built in a `nonisolated` helper: libghostty invokes these C callbacks
        // from its own threads (e.g. the renderer thread), so they must carry
        // no actor isolation — otherwise Swift's executor check traps.
        var runtime = GhosttyApp.makeRuntimeConfig()

        // M11-A2 fix (HIGH from code-reviewer): the previous version
        // assigned `self.config = config` BEFORE attempting `ghostty_app_new`.
        // On app_new failure the failure branch freed `config` AND deinit
        // would also free it (Swift considers the struct partially-init in
        // a way that can run cleanup on the stored property) — double-free.
        // Fix: keep both handles local until BOTH calls succeed, assign the
        // stored properties only at the bottom. A throw on any earlier line
        // leaves deinit nothing to free because neither stored property was
        // ever written.
        guard let appHandle = ghostty_app_new(&runtime, configHandle) else {
            ghostty_config_free(configHandle)
            GhosttyApp.logger.critical("ghostty_app_new failed")
            throw .appCreationFailed
        }
        self.config = configHandle
        self.app = appHandle
        GhosttyApp.logger.info("libghostty app created — version \(Ghostty.info.version)")
    }

    deinit {
        ghostty_app_free(app)
        ghostty_config_free(config)
    }

    /// Pump the libghostty event loop once. Drive this from a timer or display link.
    public func tick() {
        ghostty_app_tick(app)
    }

    /// Builds the runtime config. `nonisolated` so the C callbacks carry no
    /// actor isolation — libghostty calls them from arbitrary threads
    /// (in practice always the main thread for us, because `tick()` runs
    /// on main, but the contract is "no isolation guarantees").
    private nonisolated static func makeRuntimeConfig() -> ghostty_runtime_config_s {
        ghostty_runtime_config_s(
            userdata: nil,
            // macOS has no X11-style PRIMARY selection — keep this false so
            // libghostty doesn't ask us to write it on every selection drag.
            supports_selection_clipboard: false,
            wakeup_cb: { _ in },
            action_cb: Self.handleAction,
            read_clipboard_cb: Self.readClipboard,
            confirm_read_clipboard_cb: { _, _, _, _ in },
            write_clipboard_cb: Self.writeClipboard,
            close_surface_cb: Self.closeSurface
        )
    }

    /// Fired by libghostty when the surface's PTY child exits (user
    /// types `exit`, the shell crashes, etc.). Posts a notification so
    /// the workspace can drop the pane — without this the pane locks
    /// onto the "Process exited" message and the user has to ⌘W out
    /// manually. Same module-boundary trick as the clipboard cbs:
    /// resolve the per-surface userdata back to its owner via the
    /// `ClipboardOwner` protocol and post the owner object so the
    /// listener can identify which pane to close.
    public nonisolated static let surfaceDidCloseNotification = Notification.Name("herminal.surfaceDidClose")
    public nonisolated static let surfaceDidCloseProcessAliveKey = "processAlive"

    private nonisolated static let closeSurface: ghostty_runtime_close_surface_cb = { userdata, processAlive in
        guard let userdata else { return }
        let owner = Unmanaged<AnyObject>.fromOpaque(userdata).takeUnretainedValue()
        guard let surfaceOwner = owner as? ClipboardOwner else { return }
        NotificationCenter.default.post(
            name: surfaceDidCloseNotification,
            object: surfaceOwner,
            userInfo: [surfaceDidCloseProcessAliveKey: processAlive]
        )
    }

    // MARK: - Clipboard callbacks (Cmd+C / Cmd+V wiring)
    //
    // libghostty's default macOS keybindings include ⌘C → copy_to_clipboard
    // and ⌘V → paste_from_clipboard. Those actions call these two C
    // callbacks. Before this commit both were no-ops, so the keybindings
    // fired but never moved any bytes — what the user saw as "Cmd+C
    // doesn't copy".

    /// libghostty asks us to fill the clipboard with `content`. We write
    /// the first text/plain entry to NSPasteboard.general (or skip if no
    /// text entry — non-text MIME types aren't useful for a terminal).
    /// `confirm == true` would normally prompt the user (OSC 52 from a
    /// remote shell can be hostile); for now we treat both the same and
    /// just write. Wrapping that in an NSAlert is a follow-up.
    ///
    /// NSPasteboard is documented thread-safe; libghostty calls this
    /// from whichever thread is processing the ⌘C keybinding (in our
    /// runtime that's main, because `tick()` runs on main), so no extra
    /// hop is needed.
    private nonisolated static let writeClipboard: ghostty_runtime_write_clipboard_cb = { _, location, contentPtr, len, _ in
        guard location == GHOSTTY_CLIPBOARD_STANDARD else { return }
        guard let contentPtr, len > 0 else { return }
        // Walk the contents looking for the first text/plain entry.
        for i in 0..<len {
            let entry = contentPtr[i]
            guard let mimePtr = entry.mime, let dataPtr = entry.data else { continue }
            let mime = String(cString: mimePtr)
            guard mime == "text/plain" else { continue }
            let text = String(cString: dataPtr)
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
            return
        }
    }

    /// libghostty wants to paste — fetch the string clipboard and feed
    /// it back via `ghostty_surface_complete_clipboard_request`. Return
    /// true to signal "we delivered synchronously"; false would tell
    /// libghostty to fall through (the keybinding becomes a no-op).
    private nonisolated static let readClipboard: ghostty_runtime_read_clipboard_cb = { userdata, location, state in
        guard location == GHOSTTY_CLIPBOARD_STANDARD else { return false }
        guard let userdata else { return false }
        let owner = Unmanaged<AnyObject>.fromOpaque(userdata).takeUnretainedValue()
        guard let clipboardOwner = owner as? ClipboardOwner,
              let surface = clipboardOwner.surface else { return false }
        guard let text = NSPasteboard.general.string(forType: .string) else { return false }
        return text.withCString { ptr in
            ghostty_surface_complete_clipboard_request(surface, ptr, state, true)
            return true
        }
    }

    /// libghostty fired SET_TITLE / SET_TAB_TITLE (OSC 0/2 escape from
    /// the shell, or an explicit `set_tab_title` keybinding). Payload
    /// is a C string. Posted to AppKit so WorkspaceView can re-resolve
    /// the surface → session → tab and rebuild the tab strip.
    public nonisolated static let surfaceTitleDidChangeNotification = Notification.Name("herminal.surfaceTitleDidChange")
    public nonisolated static let surfaceTitleKey = "title"

    /// MOUSE_SHAPE action — terminal wants a specific cursor shape over
    /// the surface (I-beam for text, pointing-hand for URL hover, etc).
    /// Payload is the raw `ghostty_mouse_shape_e` integer; HerminalApp
    /// maps it to an NSCursor. (v0.2.5 audit pass.)
    public nonisolated static let surfaceMouseShapeDidChangeNotification = Notification.Name("herminal.surfaceMouseShapeDidChange")
    public nonisolated static let surfaceMouseShapeKey = "mouseShape"

    /// Search lifecycle — v0.3.2 polish slice 3. libghostty owns the
    /// match-finding machinery; HerminalApp owns the overlay UI and the
    /// needle text field. The four notifications match the four
    /// libghostty action callbacks (START_SEARCH, END_SEARCH,
    /// SEARCH_TOTAL, SEARCH_SELECTED).
    public nonisolated static let surfaceSearchStartNotification = Notification.Name("herminal.surfaceSearchStart")
    public nonisolated static let surfaceSearchEndNotification = Notification.Name("herminal.surfaceSearchEnd")
    public nonisolated static let surfaceSearchTotalNotification = Notification.Name("herminal.surfaceSearchTotal")
    public nonisolated static let surfaceSearchSelectedNotification = Notification.Name("herminal.surfaceSearchSelected")
    /// Count value (`ssize_t total` or `selected`). negative → unknown.
    public nonisolated static let surfaceSearchValueKey = "value"

    /// Dispatches libghostty's action callbacks. Routes:
    /// - `GHOSTTY_ACTION_RING_BELL` → `BellRegistry` (M8/A2)
    /// - `GHOSTTY_ACTION_SET_TITLE` / `SET_TAB_TITLE` → AppKit
    ///   notification so tab strip can repaint (v0.2.4 audit pass)
    ///
    /// Returns false for everything else. `nonisolated` because
    /// libghostty calls this from renderer / IO threads.
    private nonisolated static let handleAction: ghostty_runtime_action_cb = { _, target, action in
        switch action.tag {
        case GHOSTTY_ACTION_RING_BELL:
            // Bell is always per-surface — record the address so the
            // dashboard can attribute the bell to the right session.
            if target.tag == GHOSTTY_TARGET_SURFACE,
               let surface = target.target.surface {
                BellRegistry.shared.recordBell(
                    surfaceAddress: Int(bitPattern: surface)
                )
            }
            return true

        case GHOSTTY_ACTION_START_SEARCH:
            // libghostty asks the host to open the search overlay.
            // Payload contains an initial needle (often empty); the
            // overlay binds its text field to it via a notification.
            guard target.tag == GHOSTTY_TARGET_SURFACE,
                  let surface = target.target.surface,
                  let userdata = ghostty_surface_userdata(surface)
            else { return false }
            let owner = Unmanaged<AnyObject>.fromOpaque(userdata).takeUnretainedValue()
            guard let surfaceOwner = owner as? ClipboardOwner else { return false }
            let needle: String
            if let ptr = action.action.start_search.needle {
                needle = String(cString: ptr)
            } else {
                needle = ""
            }
            NotificationCenter.default.post(
                name: surfaceSearchStartNotification,
                object: surfaceOwner,
                userInfo: [surfaceSearchValueKey: needle]
            )
            return true

        case GHOSTTY_ACTION_END_SEARCH:
            guard target.tag == GHOSTTY_TARGET_SURFACE,
                  let surface = target.target.surface,
                  let userdata = ghostty_surface_userdata(surface)
            else { return false }
            let owner = Unmanaged<AnyObject>.fromOpaque(userdata).takeUnretainedValue()
            guard let surfaceOwner = owner as? ClipboardOwner else { return false }
            NotificationCenter.default.post(
                name: surfaceSearchEndNotification,
                object: surfaceOwner
            )
            return true

        case GHOSTTY_ACTION_SEARCH_TOTAL:
            guard target.tag == GHOSTTY_TARGET_SURFACE,
                  let surface = target.target.surface,
                  let userdata = ghostty_surface_userdata(surface)
            else { return false }
            let owner = Unmanaged<AnyObject>.fromOpaque(userdata).takeUnretainedValue()
            guard let surfaceOwner = owner as? ClipboardOwner else { return false }
            NotificationCenter.default.post(
                name: surfaceSearchTotalNotification,
                object: surfaceOwner,
                userInfo: [surfaceSearchValueKey: Int(action.action.search_total.total)]
            )
            return true

        case GHOSTTY_ACTION_SEARCH_SELECTED:
            guard target.tag == GHOSTTY_TARGET_SURFACE,
                  let surface = target.target.surface,
                  let userdata = ghostty_surface_userdata(surface)
            else { return false }
            let owner = Unmanaged<AnyObject>.fromOpaque(userdata).takeUnretainedValue()
            guard let surfaceOwner = owner as? ClipboardOwner else { return false }
            NotificationCenter.default.post(
                name: surfaceSearchSelectedNotification,
                object: surfaceOwner,
                userInfo: [surfaceSearchValueKey: Int(action.action.search_selected.selected)]
            )
            return true

        case GHOSTTY_ACTION_OPEN_URL:
            // libghostty detected a URL and the user clicked it. We
            // delegate to NSWorkspace which honours the user's default
            // browser + URL handler associations. Length is exposed
            // explicitly because libghostty may emit non-null-terminated
            // buffers — read exactly `len` bytes.
            guard let urlPtr = action.action.open_url.url else { return false }
            let urlLen = Int(action.action.open_url.len)
            let buffer = UnsafeBufferPointer(start: urlPtr, count: urlLen)
            let urlString = String(decoding: buffer.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            guard let url = URL(string: urlString),
                  let scheme = url.scheme?.lowercased(),
                  // Defend against `file://` / arbitrary schemes — a
                  // hostile shell could otherwise paste a payload
                  // that triggers `Open With…` on a /etc/passwd path.
                  ["http", "https", "mailto"].contains(scheme) else { return false }
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
            return true

        case GHOSTTY_ACTION_MOUSE_SHAPE:
            guard target.tag == GHOSTTY_TARGET_SURFACE,
                  let surface = target.target.surface,
                  let userdata = ghostty_surface_userdata(surface)
            else { return false }
            let owner = Unmanaged<AnyObject>.fromOpaque(userdata).takeUnretainedValue()
            guard let surfaceOwner = owner as? ClipboardOwner else { return false }
            NotificationCenter.default.post(
                name: surfaceMouseShapeDidChangeNotification,
                object: surfaceOwner,
                userInfo: [surfaceMouseShapeKey: Int(action.action.mouse_shape.rawValue)]
            )
            return true

        case GHOSTTY_ACTION_SET_TITLE, GHOSTTY_ACTION_SET_TAB_TITLE:
            // Both actions carry the same payload shape; the only
            // difference is intent (SET_TITLE = OSC 0/2 from shell,
            // SET_TAB_TITLE = explicit keybinding). For our single-pane
            // tab strip we treat them identically.
            guard target.tag == GHOSTTY_TARGET_SURFACE,
                  let surface = target.target.surface,
                  let userdata = ghostty_surface_userdata(surface),
                  let titlePtr = action.action.set_title.title
            else { return false }
            let owner = Unmanaged<AnyObject>.fromOpaque(userdata).takeUnretainedValue()
            guard let surfaceOwner = owner as? ClipboardOwner else { return false }
            let title = String(cString: titlePtr)
            NotificationCenter.default.post(
                name: surfaceTitleDidChangeNotification,
                object: surfaceOwner,
                userInfo: [surfaceTitleKey: title]
            )
            return true

        default:
            return false
        }
    }
}
