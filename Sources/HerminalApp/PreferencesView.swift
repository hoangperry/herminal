// PreferencesView — SwiftUI Settings scene. Tabs:
//   General      → first-run welcome reset, status bar
//   Appearance   → theme picker
//   Terminal     → font size, padding, cursor blink
//   Shell        → validated shell handoff for new plain-shell panes
//
// Bound to UserDefaults via @AppStorage so changes persist immediately.
// On every flip we also post Preferences.didChangeNotification so the
// AppKit chrome refreshes (theme repaint, status-bar visibility).

import AppKit
import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            AppearanceTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            TerminalTab()
                .tabItem { Label("Terminal", systemImage: "terminal") }
            ShellTab()
                .tabItem { Label("Shell", systemImage: "command") }
        }
        .frame(width: 520, height: 360)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @AppStorage(Preferences.Key.showStatusBar) private var showStatusBar = true
    @AppStorage(Preferences.Key.confirmCloseWithNote) private var confirmCloseWithNote = true
    @AppStorage(Preferences.Key.restoreSessionOnLaunch) private var restoreSessionOnLaunch = true
    @AppStorage(Preferences.Key.rerunCommandsOnRestore) private var rerunCommandsOnRestore = false
    @AppStorage(Preferences.Key.firstRunCompleted) private var firstRunCompleted = true

    var body: some View {
        let closeNoteWarningPresentation = Preferences.closeNoteWarningPresentation
        Form {
            Section("Window") {
                Toggle("Show status bar at the bottom of the window", isOn: $showStatusBar)
                    .onChange(of: showStatusBar) { _, _ in Preferences.broadcastChange() }
                Toggle(closeNoteWarningPresentation.title, isOn: $confirmCloseWithNote)
                    .onChange(of: confirmCloseWithNote) { _, _ in Preferences.broadcastChange() }
                    .help(closeNoteWarningPresentation.help)
                Toggle("Restore tabs & panes on launch", isOn: $restoreSessionOnLaunch)
                    .help("Reopen last session's tab/split layout, each pane in its last working directory.")
                Toggle("Re-run supported launches on restore", isOn: $rerunCommandsOnRestore)
                    .disabled(!restoreSessionOnLaunch)
                    .help(
                        "When restoring, replay supported ssh, Claude, tmux, and cockpit agent "
                        + "launches instead of opening a plain shell. Off by default — restoring "
                        + "stays side-effect-free unless you turn this on."
                    )
            }
            Section("Hotkey Window") {
                hotkeyStatus
            }
            Section("Onboarding") {
                Button("Show the welcome hint on next launch") {
                    firstRunCompleted = false
                }
                .help("Resets the first-run flag so the welcome overlay shows again next time you launch herminal.")
            }
        }
        .formStyle(.grouped)
    }

    private var hotkeyStatus: some View {
        let presentation = HotkeyManager.statusPresentation(
            for: hotkeyManager.registrationState
        )
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: hotkeyManager.registrationState == .registered
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill")
                    .foregroundStyle(hotkeyManager.registrationState == .registered
                        ? Color.green
                        : Color.orange)
                    .accessibilityHidden(presentation.statusIconIsDecorative)
                Text(presentation.title)
                Spacer(minLength: 0)
                if let retry = presentation.retry {
                    Button(retry.title) {
                        hotkeyManager.retryRegistration()
                    }
                    .accessibilityLabel(retry.accessibilityLabel)
                    .accessibilityHint(retry.accessibilityHint)
                    .help(retry.help)
                }
            }
            Text(presentation.help)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    @AppStorage(Preferences.Key.theme) private var themeRaw = Preferences.ThemePreference.dark.rawValue

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme", selection: $themeRaw) {
                    ForEach(Preferences.ThemePreference.allCases) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: themeRaw) { _, _ in Preferences.broadcastChange() }
            }
            Section {
                Text("`Follow System` tracks the macOS Appearance setting and switches when you change it system-wide. Manual `Dark` and `Light` ignore the system setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Terminal

private struct TerminalTab: View {
    @AppStorage(Preferences.Key.terminalFontSize) private var fontSize: Double = 13
    @AppStorage(Preferences.Key.terminalPadding) private var padding: Double = 4
    @AppStorage(Preferences.Key.cursorBlink) private var cursorBlink = true

    var body: some View {
        let fontSizePresentation = Preferences.terminalFontSizePresentation(for: fontSize)
        let paddingPresentation = Preferences.terminalPaddingPresentation(for: padding)
        Form {
            Section("Font") {
                HStack {
                    Text("Size")
                        .accessibilityHidden(true)
                    Slider(value: $fontSize, in: 9...24, step: 1) {
                        Text("Font size")
                    } minimumValueLabel: {
                        Text("9")
                            .font(.caption)
                            .accessibilityHidden(true)
                    } maximumValueLabel: {
                        Text("24")
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                    .labelsHidden()
                    .accessibilityLabel(fontSizePresentation.accessibilityLabel)
                    .accessibilityValue(fontSizePresentation.accessibilityValue)
                    .accessibilityHint(fontSizePresentation.accessibilityHint)
                    Text(fontSizePresentation.visibleValue)
                        .monospacedDigit()
                        .frame(width: 30, alignment: .trailing)
                        .accessibilityHidden(true)
                }
                .onChange(of: fontSize) { _, _ in Preferences.broadcastChange() }
            }
            Section("Layout") {
                HStack {
                    Text("Padding")
                        .accessibilityHidden(true)
                    Slider(value: $padding, in: 0...16, step: 1) {
                        Text("Padding")
                    } minimumValueLabel: {
                        Text("0")
                            .font(.caption)
                            .accessibilityHidden(true)
                    } maximumValueLabel: {
                        Text("16")
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                    .labelsHidden()
                    .accessibilityLabel(paddingPresentation.accessibilityLabel)
                    .accessibilityValue(paddingPresentation.accessibilityValue)
                    .accessibilityHint(paddingPresentation.accessibilityHint)
                    Text(paddingPresentation.visibleValue)
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                        .accessibilityHidden(true)
                }
                .onChange(of: padding) { _, _ in Preferences.broadcastChange() }
            }
            Section("Cursor") {
                Toggle("Blink cursor when herminal has focus", isOn: $cursorBlink)
                    .onChange(of: cursorBlink) { _, _ in Preferences.broadcastChange() }
            }
            Section {
                Text("Font + padding changes apply to NEW tabs. Existing tabs keep their current settings until closed — libghostty doesn't expose a runtime resize for these.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shell

private struct ShellTab: View {
    @AppStorage(Preferences.Key.defaultShellPath) private var shellPath = ""

    var body: some View {
        let presentation = Preferences.shellOverridePresentation(for: shellPath)
        Form {
            Section("Shell handoff") {
                HStack {
                    TextField("/bin/zsh", text: $shellPath)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Preferences.broadcastChange() }
                        .help(presentation.fieldAccessibilityHint)
                        .accessibilityLabel("Shell handoff path")
                        .accessibilityHint(presentation.fieldAccessibilityHint)
                    Button("Use macOS Login Shell") {
                        shellPath = ""
                        Preferences.broadcastChange()
                    }
                    .disabled(!presentation.canResetToLoginShell)
                    .accessibilityLabel("Use macOS login shell")
                    .accessibilityHint(
                        presentation.canResetToLoginShell
                            ? "Clears the override. New plain-shell tabs and splits use your macOS login shell. Existing panes keep running their current shell."
                            : "Already using your macOS login shell for new plain-shell tabs and splits."
                    )
                    .help("Clear the override and use your macOS login shell for new plain-shell tabs and splits.")
                }
            }
            Section {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: presentation.systemImage)
                        .foregroundStyle(statusColor(for: presentation.kind))
                        .accessibilityHidden(true)
                    Text(presentation.message)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.primary)
                }
                .font(.caption)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(presentation.statusAccessibilityLabel)
            }
        }
        .formStyle(.grouped)
        .onChange(of: presentation) { previous, current in
            announceStatusChange(from: previous, to: current)
        }
    }

    private func announceStatusChange(
        from previous: Preferences.ShellOverridePresentation,
        to current: Preferences.ShellOverridePresentation
    ) {
        guard let announcement = Preferences.shellOverrideStatusAnnouncement(
            from: previous,
            to: current
        ) else { return }
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: announcement,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ]
        )
    }

    private func statusColor(
        for kind: Preferences.ShellOverridePresentation.Kind
    ) -> Color {
        switch kind {
        case .inherited:
            return .secondary
        case .active:
            return HerminalDesign.Palette.accent
        case .invalid:
            return .red
        }
    }
}
