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
    struct CloseNoteWarningPresentation: Equatable {
        let title: String
        let help: String
    }

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
    /// AppDelegate and broadcasts through the normal live-update path).
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
            Key.defaultShellPath: "",  // empty = use the macOS login shell
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

    struct TerminalControlPresentation: Equatable {
        let visibleValue: String
        let accessibilityLabel: String
        let accessibilityValue: String
        let accessibilityHint: String
    }

    static func terminalFontSizePresentation(
        for value: Double
    ) -> TerminalControlPresentation {
        let points = Int(value.rounded())
        return TerminalControlPresentation(
            visibleValue: "\(points)",
            accessibilityLabel: "Terminal font size",
            accessibilityValue: accessibilityMeasurementValue(
                for: points,
                singularUnit: "point",
                pluralUnit: "points"
            ),
            accessibilityHint: "Applies to new tabs."
        )
    }

    static func terminalPaddingPresentation(
        for value: Double
    ) -> TerminalControlPresentation {
        let pixels = Int(value.rounded())
        return TerminalControlPresentation(
            visibleValue: "\(pixels)px",
            accessibilityLabel: "Terminal padding",
            accessibilityValue: accessibilityMeasurementValue(
                for: pixels,
                singularUnit: "pixel",
                pluralUnit: "pixels"
            ),
            accessibilityHint: "Applies to new tabs."
        )
    }

    private static func accessibilityMeasurementValue(
        for roundedValue: Int,
        singularUnit: String,
        pluralUnit: String
    ) -> String {
        let unit = roundedValue == 1 ? singularUnit : pluralUnit
        return "\(roundedValue) \(unit)"
    }

    public static var cursorBlink: Bool {
        UserDefaults.standard.bool(forKey: Key.cursorBlink)
    }

    public static var defaultShellPath: String {
        UserDefaults.standard.string(forKey: Key.defaultShellPath) ?? ""
    }

    struct ShellOverridePresentation: Equatable {
        enum Kind: Equatable {
            case inherited
            case active
            case invalid
        }

        enum AnnouncementIdentity: Equatable {
            case inherited
            case active(String)
            case unsafeCharacters
            case relativePath
            case temporaryPath
            case notExecutable
        }

        let kind: Kind
        let announcementIdentity: AnnouncementIdentity
        let message: String
        let fieldAccessibilityHint: String
        let statusAccessibilityLabel: String
        let systemImage: String
        let canResetToLoginShell: Bool
    }

    private enum ShellOverrideValidation: Equatable {
        case inherited
        case valid(savedPath: String, launchPath: String)
        case unsafeCharacters
        case relativePath
        case temporaryPath
        case notExecutable(String)
    }

    static func shellOverridePresentation(
        for rawPath: String,
        isExecutable: ((String) -> Bool)? = nil,
        resolvePath: (String) -> String = {
            URL(fileURLWithPath: $0).resolvingSymlinksInPath().path
        }
    ) -> ShellOverridePresentation {
        let validation = shellOverrideValidation(
            for: rawPath,
            isExecutable: isExecutable ?? isExecutableRegularFile,
            resolvePath: resolvePath
        )
        let kind: ShellOverridePresentation.Kind
        let announcementIdentity: ShellOverridePresentation.AnnouncementIdentity
        let message: String
        let systemImage: String

        switch validation {
        case .inherited:
            kind = .inherited
            announcementIdentity = .inherited
            message = "Using your macOS login shell for new plain-shell tabs and splits."
            systemImage = "checkmark.circle"
        case let .valid(savedPath, _):
            kind = .active
            announcementIdentity = .active(savedPath)
            message = "New plain-shell tabs and splits start your macOS login shell, then request a handoff to \(savedPath). Login-shell startup files run first; existing panes are unchanged."
            systemImage = "checkmark.circle.fill"
        case .unsafeCharacters:
            kind = .invalid
            announcementIdentity = .unsafeCharacters
            message = "Invalid shell path: control characters aren't allowed. This value is ignored."
            systemImage = "exclamationmark.triangle"
        case .relativePath:
            kind = .invalid
            announcementIdentity = .relativePath
            message = "Invalid shell path: enter an absolute path, such as /opt/homebrew/bin/fish. This value is ignored."
            systemImage = "exclamationmark.triangle"
        case .temporaryPath:
            kind = .invalid
            announcementIdentity = .temporaryPath
            message = "Invalid shell path: executables under /tmp aren't allowed. This value is ignored."
            systemImage = "exclamationmark.triangle"
        case let .notExecutable(path):
            kind = .invalid
            announcementIdentity = .notExecutable
            message = "Invalid shell path: no executable file exists at \(path). This value is ignored."
            systemImage = "exclamationmark.triangle"
        }

        return ShellOverridePresentation(
            kind: kind,
            announcementIdentity: announcementIdentity,
            message: message,
            fieldAccessibilityHint: shellOverrideFieldAccessibilityHint,
            statusAccessibilityLabel: "Shell override status. \(message)",
            systemImage: systemImage,
            canResetToLoginShell: validation != .inherited
        )
    }

    private static let shellOverrideFieldAccessibilityHint =
        "Set an absolute executable path, such as /opt/homebrew/bin/fish. New plain-shell tabs and splits start your macOS login shell, then request a handoff to this path."

    static func shellOverrideStatusAnnouncement(
        from previous: ShellOverridePresentation,
        to current: ShellOverridePresentation
    ) -> String? {
        guard previous.announcementIdentity != current.announcementIdentity else { return nil }
        return current.statusAccessibilityLabel
    }

    static func validatedShellOverridePath(
        for rawPath: String,
        isExecutable: ((String) -> Bool)? = nil,
        resolvePath: (String) -> String = {
            URL(fileURLWithPath: $0).resolvingSymlinksInPath().path
        }
    ) -> String? {
        guard case let .valid(_, path) = shellOverrideValidation(
            for: rawPath,
            isExecutable: isExecutable ?? isExecutableRegularFile,
            resolvePath: resolvePath
        ) else { return nil }
        return path
    }

    /// Validates the stored path before a new plain-shell pane uses it as a
    /// bootstrap override. Empty input means "use the macOS login shell" and
    /// returns nil.
    public static func validatedDefaultShellPath() -> String? {
        validatedShellOverridePath(for: defaultShellPath)
    }

    private static func shellOverrideValidation(
        for rawPath: String,
        isExecutable: (String) -> Bool,
        resolvePath: (String) -> String
    ) -> ShellOverrideValidation {
        guard rawPath.rangeOfCharacter(from: .controlCharacters) == nil else {
            return .unsafeCharacters
        }
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .inherited }

        let savedPath = (trimmed as NSString).standardizingPath
        guard savedPath.hasPrefix("/") else { return .relativePath }
        let launchPath = (resolvePath(savedPath) as NSString).standardizingPath
        guard !isTemporaryShellPath(savedPath),
              !isTemporaryShellPath(launchPath) else { return .temporaryPath }
        guard isExecutable(launchPath) else { return .notExecutable(savedPath) }
        return .valid(savedPath: savedPath, launchPath: launchPath)
    }

    private static func isTemporaryShellPath(_ path: String) -> Bool {
        path == "/tmp" || path.hasPrefix("/tmp/")
            || path == "/private/tmp" || path.hasPrefix("/private/tmp/")
    }

    private static func isExecutableRegularFile(_ path: String) -> Bool {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(
            atPath: path,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue else {
            return false
        }
        return FileManager.default.isExecutableFile(atPath: path)
    }

    public static var showStatusBar: Bool {
        UserDefaults.standard.bool(forKey: Key.showStatusBar)
    }

    /// Shared write path for menu and command-palette visibility toggles.
    /// Keeping persistence and the AppKit refresh notification together
    /// prevents callers from changing the stored value without relayout.
    @discardableResult
    public static func toggleStatusBarVisibility() -> Bool {
        let isVisible = !showStatusBar
        UserDefaults.standard.set(isVisible, forKey: Key.showStatusBar)
        broadcastChange()
        return isVisible
    }

    public static var confirmCloseWithNote: Bool {
        UserDefaults.standard.bool(forKey: Key.confirmCloseWithNote)
    }

    static let closeNotesWarningHelpText =
        "Live-work warnings remain on to protect running SSH, tmux, and agent sessions."

    static let closeNoteWarningPresentation = CloseNoteWarningPresentation(
        title: "Warn when closing sessions with notes",
        help: closeNotesWarningHelpText
    )

    public static var restoreSessionOnLaunch: Bool {
        UserDefaults.standard.bool(forKey: Key.restoreSessionOnLaunch)
    }

    /// Opt-in: replay each pane's supported Herminal launch intent on
    /// restore instead of opening a plain shell. Default false (see
    /// registered defaults) — restoring stays side-effect-free unless asked.
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
