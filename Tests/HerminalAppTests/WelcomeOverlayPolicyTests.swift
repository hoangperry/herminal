import AppKit
import SwiftUI
import Testing

@testable import HerminalApp

@Suite("Welcome overlay policy")
@MainActor
struct WelcomeOverlayPolicyTests {
    private final class TestTerminalPaneView: NSView {
        override var acceptsFirstResponder: Bool { true }
    }

    @Test("only explicit action and Escape dismiss one-shot onboarding")
    func explicitDismissalPolicy() {
        #expect(WelcomeOverlayView.shouldDismiss(from: .primaryAction))
        #expect(WelcomeOverlayView.shouldDismiss(from: .escape))
        #expect(!WelcomeOverlayView.shouldDismiss(from: .backdrop))
    }

    @Test("the primary action owns initial keyboard focus")
    func initialFocusTarget() {
        #expect(WelcomeOverlayView.initialFocusTarget == .primaryAction)
    }

    @Test("welcome content presents a modal heading to assistive technology")
    func accessibilityPresentation() {
        #expect(
            WelcomeOverlayView.accessibilityPresentation == .init(
                heading: "Welcome to herminal",
                isModal: true
            )
        )
    }

    @Test("shortcut rows combine action and key equivalent into one announcement")
    func shortcutAnnouncement() {
        #expect(
            WelcomeOverlayView.shortcutAccessibilityLabel(
                keys: "⌘⇧P",
                action: "Command palette — every action, searchable"
            ) == "Command palette — every action, searchable. Shortcut ⌘⇧P"
        )
    }

    @Test("Escape dismisses the hosted overlay once and restores pane focus")
    func escapeDismissalRemovesOverlayMarksCompletionOnceAndRestoresFocus() {
        let defaults = UserDefaults.standard
        let key = Preferences.Key.firstRunCompleted
        let originalValue = defaults.object(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(false, forKey: key)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        defer { window.close() }

        let container = NSView(frame: window.contentView?.bounds ?? .zero)
        container.autoresizingMask = [.width, .height]
        window.contentView = container

        let terminalPane = TestTerminalPaneView(frame: container.bounds)
        terminalPane.autoresizingMask = [.width, .height]
        container.addSubview(terminalPane)

        var completionMarks = 0
        var overlay: NSHostingView<WelcomeOverlayView>!
        overlay = NSHostingView(rootView: WelcomeOverlayView(onDismiss: {
            _ = WorkspaceView.completeWelcomeOverlayDismissal(
                overlay: overlay,
                window: window,
                returningFocusTo: terminalPane,
                markCompleted: {
                    completionMarks += 1
                    Preferences.markFirstRunCompleted()
                }
            )
        }))
        overlay.frame = container.bounds
        overlay.autoresizingMask = [.width, .height]
        container.addSubview(overlay)

        #expect(overlay.superview === container)
        #expect(!Preferences.firstRunCompleted)
        #expect(window.firstResponder !== terminalPane)

        overlay.rootView.requestDismissal(from: .escape)

        #expect(overlay.superview == nil)
        #expect(Preferences.firstRunCompleted)
        #expect(completionMarks == 1)
        #expect(window.firstResponder === terminalPane)

        overlay.rootView.requestDismissal(from: .escape)

        #expect(completionMarks == 1)
        #expect(window.firstResponder === terminalPane)
    }
}
