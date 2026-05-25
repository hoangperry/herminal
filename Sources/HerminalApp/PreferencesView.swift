// PreferencesView — SwiftUI Settings scene. Tabs:
//   General      → first-run welcome reset, status bar
//   Appearance   → theme picker
//   Terminal     → font size, padding, cursor blink
//   Shell        → default shell override
//
// Bound to UserDefaults via @AppStorage so changes persist immediately.
// On every flip we also post Preferences.didChangeNotification so the
// AppKit chrome refreshes (theme repaint, status-bar visibility).

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
    @AppStorage(Preferences.Key.showStatusBar) private var showStatusBar = true
    @AppStorage(Preferences.Key.confirmCloseWithNote) private var confirmCloseWithNote = true
    @AppStorage(Preferences.Key.firstRunCompleted) private var firstRunCompleted = true

    var body: some View {
        Form {
            Section("Window") {
                Toggle("Show status bar at the bottom of the window", isOn: $showStatusBar)
                    .onChange(of: showStatusBar) { _, _ in Preferences.broadcastChange() }
                Toggle("Confirm before closing a tab with notes", isOn: $confirmCloseWithNote)
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
        Form {
            Section("Font") {
                HStack {
                    Text("Size")
                    Slider(value: $fontSize, in: 9...24, step: 1) {
                        Text("Font size")
                    } minimumValueLabel: {
                        Text("9").font(.caption)
                    } maximumValueLabel: {
                        Text("24").font(.caption)
                    }
                    Text("\(Int(fontSize))")
                        .monospacedDigit()
                        .frame(width: 30, alignment: .trailing)
                }
                .onChange(of: fontSize) { _, _ in Preferences.broadcastChange() }
            }
            Section("Layout") {
                HStack {
                    Text("Padding")
                    Slider(value: $padding, in: 0...16, step: 1)
                    Text("\(Int(padding))px")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
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
        Form {
            Section("Default shell") {
                HStack {
                    TextField("/bin/zsh", text: $shellPath)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Preferences.broadcastChange() }
                    Button("Use $SHELL") {
                        shellPath = ""
                        Preferences.broadcastChange()
                    }
                }
            }
            Section {
                if shellPath.isEmpty {
                    Text("Empty = inherit from the `$SHELL` environment variable (default behaviour). Set an absolute path like `/opt/homebrew/bin/fish` to override per-tab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("All new tabs will spawn `\(shellPath)`. Existing tabs keep their current shell.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
