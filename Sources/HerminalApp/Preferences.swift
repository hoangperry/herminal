// Preferences — owner-facing tunable settings, persisted via UserDefaults.
//
// Single source of truth for everything you'd reach for in a "Settings"
// window. Each setting:
// - Has a default that matches the M1-M11 hardcoded behaviour, so
//   upgrading to M12 changes nothing visible until the owner opens
//   Settings.
// - Is observable via SwiftUI's @AppStorage so the Settings UI binds
//   directly without a manual broadcast layer.
// - Is also readable from AppKit (WorkspaceView, AppDelegate) via the
//   `Preferences` enum's static accessors, which read the same
//   UserDefaults keys.
//
// One file, two access shapes — SwiftUI gets reactive bindings, AppKit
// gets sync reads. The defaults dictionary keeps both honest about
// initial values.

import Foundation
import SwiftUI

public enum Preferences {

    // MARK: - Keys

    /// UserDefaults keys are namespaced under `preferences.` so we can
    /// grep for the full set and so they don't clash with future legacy
    /// keys (e.g. window-state) that AppKit will write directly.
    public enum Key {
        public static let theme = "preferences.theme"                       // dark / light / system
        public static let terminalFontSize = "preferences.terminal.fontSize"
        public static let terminalPadding = "preferences.terminal.padding"
        public static let cursorBlink = "preferences.terminal.cursorBlink"
        public static let defaultShellPath = "preferences.shell.path"
        public static let showStatusBar = "preferences.window.statusBar"
        public static let confirmCloseWithNote = "preferences.window.confirmCloseWithNote"
        public static let restoreSessionOnLaunch = "preferences.window.restoreSession"
        public static let rerunCommandsOnRestore = "preferences.window.rerunCommandsOnRestore"
        public static let firstRunCompleted = "preferences.firstRun.completed"
    }

    /// Theme options exposed in Settings. Mirrors `HerminalDesign.Theme`
    /// for the dark/light values, plus `.system` which follows the
    /// macOS Appearance setting (NSAppearance observation lives in
    /// WorkspaceView).
    public enum ThemePreference: String, CaseIterable, Identifiable {
        case dark, light, system
        public var id: String { rawValue }
        public var displayName: String {
            switch self {
            case .dark: return "Dark"
            case .light: return "Light"
            case .system: return "Follow System"
            }
        }
    }

    // MARK: - Defaults

    /// Defaults registered at app launch so first-launch reads return
    /// stable values even though no entry exists yet. Keep in sync with
    /// the documented behaviour from M1-M11; changing one of these is
    /// a user-facing behaviour change and belongs in CHANGELOG.
    ///
    /// Implemented as a function (not a static let) so Swift 6 strict
    /// concurrency doesn't flag the `[String: Any]` dictionary as
    /// non-Sendable shared global state. Called once at launch, so the
    /// per-call allocation is irrelevant.
    public static func defaultsDictionary() -> [String: Any] {
        [
            Key.theme: ThemePreference.dark.rawValue,
            Key.terminalFontSize: 13.0,
            Key.terminalPadding: 4.0,
            Key.cursorBlink: true,
            Key.defaultShellPath: "",  // empty = inherit from $SHELL
            Key.showStatusBar: true,
            Key.confirmCloseWithNote: true,
            Key.restoreSessionOnLaunch: true,
            Key.rerunCommandsOnRestore: false,  // conservative: layout+cwd only
            Key.firstRunCompleted: false,
        ]
    }

    /// Call ONCE at process start from AppDelegate.
    public static func registerDefaults() {
        UserDefaults.standard.register(defaults: defaultsDictionary())
    }

    // MARK: - AppKit-side static accessors

    public static var theme: ThemePreference {
        let raw = UserDefaults.standard.string(forKey: Key.theme) ?? ThemePreference.dark.rawValue
        return ThemePreference(rawValue: raw) ?? .dark
    }

    public static var terminalFontSize: Double {
        UserDefaults.standard.double(forKey: Key.terminalFontSize)
    }

    public static var terminalPadding: Double {
        UserDefaults.standard.double(forKey: Key.terminalPadding)
    }

    public static var cursorBlink: Bool {
        UserDefaults.standard.bool(forKey: Key.cursorBlink)
    }

    public static var defaultShellPath: String {
        UserDefaults.standard.string(forKey: Key.defaultShellPath) ?? ""
    }

    /// Validates a shell path before passing it to libghostty as
    /// `config.command`. Returns nil for paths that should be rejected.
    /// Callers that hand the raw `defaultShellPath` to libghostty MUST
    /// route through this helper — a UserDefaults plist is non-sandboxed
    /// and an attacker who can write the user's defaults can otherwise
    /// pre-stage `/tmp/evil-shell` (or a symlink to one). Empty input is
    /// treated as "inherit from $SHELL" and returns nil so the caller
    /// falls back to the default behaviour. (M12 review MEDIUM —
    /// security-reviewer finding 3; full consumption gated to M13+.)
    public static func validatedDefaultShellPath() -> String? {
        let raw = defaultShellPath
        guard !raw.isEmpty else { return nil }
        let absolute = (raw as NSString).standardizingPath
        guard absolute.hasPrefix("/"),
              !absolute.hasPrefix("/tmp"),
              !absolute.hasPrefix("/private/tmp"),
              FileManager.default.isExecutableFile(atPath: absolute) else { return nil }
        return absolute
    }

    public static var showStatusBar: Bool {
        UserDefaults.standard.bool(forKey: Key.showStatusBar)
    }

    public static var confirmCloseWithNote: Bool {
        UserDefaults.standard.bool(forKey: Key.confirmCloseWithNote)
    }

    public static var restoreSessionOnLaunch: Bool {
        UserDefaults.standard.bool(forKey: Key.restoreSessionOnLaunch)
    }

    /// Opt-in: replay each pane's ssh/claude spawn command on restore
    /// instead of opening a plain shell. Default false (see registered
    /// defaults) — restoring stays side-effect-free unless asked.
    public static var rerunCommandsOnRestore: Bool {
        UserDefaults.standard.bool(forKey: Key.rerunCommandsOnRestore)
    }

    public static var firstRunCompleted: Bool {
        UserDefaults.standard.bool(forKey: Key.firstRunCompleted)
    }

    public static func markFirstRunCompleted() {
        UserDefaults.standard.set(true, forKey: Key.firstRunCompleted)
    }

    // MARK: - Live-update notification

    /// Posted whenever a Settings change should ripple to AppKit code
    /// that doesn't observe UserDefaults directly. Listeners: WorkspaceView
    /// (theme repaint, status-bar visibility, padding/font passdown to
    /// libghostty), AppDelegate (rebuilds menu if shortcuts ever become
    /// configurable).
    public static let didChangeNotification = Notification.Name("herminal.preferences.didChange")

    /// Convenience for SwiftUI views to call after a setting flip — the
    /// AppStorage write itself is observable, but AppKit views need the
    /// post() to know to re-read.
    ///
    /// CONTRACT — every `@AppStorage`-backed control in `PreferencesView`
    /// must follow its write with an `.onChange { Preferences.broadcastChange() }`
    /// (or `.onSubmit` for text fields). The relationship is enforced by
    /// convention, not the type system, so adding a new toggle without
    /// the broadcast call silently fails to ripple to AppKit listeners.
    /// If this list ever crosses ~10 settings, consider an `@AppStorage`
    /// wrapper that auto-posts. (M12 review LOW — code-reviewer finding 7.)
    public static func broadcastChange() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
