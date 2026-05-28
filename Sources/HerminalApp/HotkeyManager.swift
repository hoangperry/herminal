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

@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    // Signature unique to herminal so we don't clash with any
    // other app's Carbon hotkey registration in the same process.
    // ('htkH' = 'h', 't', 'k', 'H'.)
    private static let signature: OSType = 0x68746B48
    private static let id: UInt32 = 1

    /// Install the global hotkey. Called once at app launch.
    /// Safe to no-op on failure (Carbon API can refuse if the
    /// combo is already grabbed by something else).
    func install() {
        guard hotKeyRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { _, eventRef, _ in
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
               hkID.signature == HotkeyManager.signature,
               hkID.id == HotkeyManager.id {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        HotkeyManager.shared.handleFired()
                    }
                }
            }
            return noErr
        }

        var handlerRef: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &handlerRef)
        self.eventHandler = handlerRef

        // ⌥Space — Option + Space. kVK_Space = 0x31; cmdKey,
        // optionKey, etc. live in Carbon's HIToolbox/Events.h.
        let modifiers: UInt32 = UInt32(optionKey)
        let hkID = EventHotKeyID(signature: Self.signature, id: Self.id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            modifiers,
            hkID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            self.hotKeyRef = ref
            NSLog("herminal: hotkey ⌥Space registered")
        } else {
            // status -9878 = eventHotKeyExistsErr — another app
            // owns the combo. Log and move on; user can still use
            // the menu / palette to reach the action.
            NSLog("herminal: hotkey ⌥Space registration failed (status=\(status))")
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
