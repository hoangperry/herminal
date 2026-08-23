// HotkeyManager — global ⌥Space (Option+Space) shortcut that
// toggles herminal's window visibility from anywhere on macOS.
//
// This is iTerm2's "gateway drug" feature — a single binding that
// surfaces the terminal from inside any other app. We use the
// Carbon RegisterEventHotKey API (still the only sanctioned way to
// register a SYSTEM-WIDE hotkey on macOS that does NOT require the
// Accessibility permission prompt). NSEvent.addGlobalMonitorForEvents
// would need that prompt; Carbon doesn't.
//
// The actual show/hide flow:
//  - Hidden → orderFront + raise to .floating temporarily so the
//    activation transition feels instant, then drop back to normal.
//  - Visible + key window → orderOut (hide).
//
// Centred on the active screen. Future enhancement: slide-down from
// the top edge (Quake mode). For v0.3.1 the toggle alone is enough.

import AppKit
import Carbon.HIToolbox
import Combine

private enum HerminalHotkey {
    static let signature: OSType = 0x68746B48
    static let id: UInt32 = 1
}

@MainActor
protocol HotkeyRegistrationDriving: AnyObject {
    var hasRegisteredHotKey: Bool { get }
    func installEventHandlerIfNeeded(callback: EventHandlerUPP) -> OSStatus
    func registerHotKey() -> OSStatus
}

@MainActor
private final class CarbonHotkeyRegistrationDriver: HotkeyRegistrationDriving {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    var hasRegisteredHotKey: Bool { hotKeyRef != nil }

    func installEventHandlerIfNeeded(callback: EventHandlerUPP) -> OSStatus {
        guard eventHandler == nil else { return noErr }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var handlerRef: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &handlerRef
        )
        guard status == noErr, let handlerRef else {
            return status == noErr ? OSStatus(paramErr) : status
        }
        eventHandler = handlerRef
        return noErr
    }

    func registerHotKey() -> OSStatus {
        guard hotKeyRef == nil else { return noErr }
        let modifiers = UInt32(optionKey)
        let hotkeyID = EventHotKeyID(
            signature: HerminalHotkey.signature,
            id: HerminalHotkey.id
        )
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        if status == noErr, let reference {
            hotKeyRef = reference
        }
        return status
    }
}

@MainActor
final class HotkeyManager: ObservableObject {
    enum RegistrationState: Equatable, Sendable {
        case registered
        case shortcutConflict
        case registrationFailed
    }

    struct RetryPresentation: Equatable, Sendable {
        let title: String
        let accessibilityLabel: String
        let accessibilityHint: String
        let help: String
    }

    struct StatusPresentation: Equatable, Sendable {
        let title: String
        let help: String
        let retry: RetryPresentation?
        let statusIconIsDecorative: Bool

        var showsRetry: Bool { retry != nil }
    }

    static let shared = HotkeyManager()

    private let registrationDriver: any HotkeyRegistrationDriving
    @Published private(set) var registrationState: RegistrationState = .registrationFailed

    init(registrationDriver: (any HotkeyRegistrationDriving)? = nil) {
        self.registrationDriver = registrationDriver ?? CarbonHotkeyRegistrationDriver()
    }

    /// Install the global hotkey. Called once at app launch.
    /// Safe to no-op on failure (Carbon API can refuse if the
    /// combo is already grabbed by something else).
    func install() {
        guard !registrationDriver.hasRegisteredHotKey else {
            registrationState = .registered
            return
        }
        let handlerStatus = registrationDriver.installEventHandlerIfNeeded(
            callback: Self.eventHandlerCallback
        )
        guard handlerStatus == noErr else {
            registrationState = .registrationFailed
            NSLog("herminal: hotkey event handler installation failed (status=\(handlerStatus))")
            return
        }

        let status = registrationDriver.registerHotKey()
        let mappedState = Self.registrationState(for: status)
        if mappedState == .registered, registrationDriver.hasRegisteredHotKey {
            registrationState = .registered
            NSLog("herminal: hotkey ⌥Space registered")
        } else {
            registrationState = mappedState == .registered
                ? .registrationFailed
                : mappedState
            // status -9878 = eventHotKeyExistsErr — another app
            // owns the combo. Keep the raw value in diagnostics only;
            // Preferences presents actionable, human-readable recovery.
            NSLog("herminal: hotkey ⌥Space registration failed (status=\(status))")
        }
    }

    func retryRegistration() {
        guard registrationState != .registered else { return }
        install()
    }

    nonisolated static func registrationState(for status: OSStatus) -> RegistrationState {
        if status == noErr { return .registered }
        if status == OSStatus(eventHotKeyExistsErr) { return .shortcutConflict }
        return .registrationFailed
    }

    nonisolated static func statusPresentation(
        for state: RegistrationState
    ) -> StatusPresentation {
        switch state {
        case .registered:
            return StatusPresentation(
                title: "Global hotkey active",
                help: "Press ⌥Space from any app to show or hide herminal.",
                retry: nil,
                statusIconIsDecorative: true
            )
        case .shortcutConflict:
            return StatusPresentation(
                title: "Global hotkey unavailable",
                help: "Another app is already using ⌥Space. You can still use Window → Show Hotkey Window or Command Palette.",
                retry: retryPresentation(),
                statusIconIsDecorative: true
            )
        case .registrationFailed:
            return StatusPresentation(
                title: "Global hotkey unavailable",
                help: "herminal couldn't register ⌥Space. You can still use Window → Show Hotkey Window or Command Palette.",
                retry: retryPresentation(),
                statusIconIsDecorative: true
            )
        }
    }

    private nonisolated static func retryPresentation() -> RetryPresentation {
        RetryPresentation(
            title: "Retry",
            accessibilityLabel: "Retry global hotkey registration",
            accessibilityHint: "Attempts to register Option-Space again",
            help: "Try to register ⌥Space again"
        )
    }

    private static var eventHandlerCallback: EventHandlerUPP {
        { _, eventRef, _ in
            guard let eventRef else { return noErr }
            var hkID = EventHotKeyID()
            let err = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            if err == noErr,
               hkID.signature == HerminalHotkey.signature,
               hkID.id == HerminalHotkey.id {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        HotkeyManager.shared.handleFired()
                    }
                }
            }
            return noErr
        }
    }

    /// Toggle the main herminal window. Called by both the Carbon
    /// hotkey AND the menu-bar `Window → Show Hotkey Window` entry,
    /// so users without the global hotkey path still have access.
    func handleFired() {
        guard let window = mainWindow() else { return }
        if window.isVisible && window.isKeyWindow {
            window.orderOut(nil)
        } else {
            // Bring the app fully forward — `activate` alone keeps the
            // previously-frontmost app in the active list, leading to
            // the herminal window appearing behind the caller. Pair
            // with `makeKeyAndOrderFront` to ensure focus.
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func mainWindow() -> NSWindow? {
        // Prefer the first non-Preferences, non-Palette herminal
        // window. Preferences + Palette are floating panels that we
        // don't want to toggle.
        for window in NSApp.windows where window.title == "herminal" && !(window is NSPanel) {
            return window
        }
        return NSApp.windows.first
    }
}
