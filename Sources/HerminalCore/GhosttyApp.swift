// GhosttyApp — owns the single libghostty `ghostty_app_t` instance.
// This is the app-level handle: configuration + runtime callbacks + event-loop tick.
// Surfaces (terminal views) are created against the app handle exposed here.

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
    /// actor isolation — libghostty calls them from arbitrary threads.
    /// For the Month-1 spike a steady timer drives ticks, so `wakeup_cb` is a no-op.
    private nonisolated static func makeRuntimeConfig() -> ghostty_runtime_config_s {
        ghostty_runtime_config_s(
            userdata: nil,
            supports_selection_clipboard: false,
            wakeup_cb: { _ in },
            action_cb: Self.handleAction,
            read_clipboard_cb: { _, _, _ in false },
            confirm_read_clipboard_cb: { _, _, _, _ in },
            write_clipboard_cb: { _, _, _, _, _ in },
            close_surface_cb: { _, _ in }
        )
    }

    /// Dispatches libghostty's action callbacks. Currently routes
    /// `GHOSTTY_ACTION_RING_BELL` to `BellRegistry` for the agent-needs-input
    /// detection (M8/A2 / Q6-001) and returns false (= unhandled) for
    /// everything else. `nonisolated` because libghostty calls this from
    /// renderer / IO threads.
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
        default:
            return false
        }
    }
}
