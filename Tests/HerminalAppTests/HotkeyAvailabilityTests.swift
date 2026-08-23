import Carbon.HIToolbox
import Testing
@testable import HerminalApp

@Suite("Hotkey availability")
@MainActor
struct HotkeyAvailabilityTests {
    private final class StubRegistrationDriver: HotkeyRegistrationDriving {
        struct Attempt {
            let status: OSStatus
            let producesReference: Bool
        }

        private(set) var hasRegisteredHotKey = false
        private(set) var registrationCallCount = 0
        var handlerStatus: OSStatus = noErr
        var attempts: [Attempt]

        init(attempts: [Attempt]) {
            self.attempts = attempts
        }

        func installEventHandlerIfNeeded(callback _: EventHandlerUPP) -> OSStatus {
            handlerStatus
        }

        func registerHotKey() -> OSStatus {
            let index = min(registrationCallCount, attempts.count - 1)
            let attempt = attempts[index]
            registrationCallCount += 1
            hasRegisteredHotKey = attempt.producesReference
            return attempt.status
        }
    }

    @Test("registered status presents the active global hotkey state")
    func registeredStatusPresentation() {
        let presentation = HotkeyManager.statusPresentation(for: .registered)

        #expect(presentation.title == "Global hotkey active")
        #expect(
            presentation.help
                == "Press ⌥Space from any app to show or hide herminal."
        )
        #expect(!presentation.showsRetry)
        #expect(presentation.retry == nil)
        #expect(presentation.statusIconIsDecorative)
        #expect(!presentation.title.contains("9878"))
        #expect(!presentation.help.contains("9878"))
    }

    @Test("shortcut conflicts present specific fallback guidance without raw status text")
    func shortcutConflictStatusPresentation() {
        let presentation = HotkeyManager.statusPresentation(for: .shortcutConflict)

        #expect(presentation.title == "Global hotkey unavailable")
        #expect(
            presentation.help
                == "Another app is already using ⌥Space. You can still use Window → Show Hotkey Window or Command Palette."
        )
        #expect(presentation.showsRetry)
        #expect(presentation.retry?.title == "Retry")
        #expect(
            presentation.retry?.accessibilityLabel
                == "Retry global hotkey registration"
        )
        #expect(
            presentation.retry?.accessibilityHint
                == "Attempts to register Option-Space again"
        )
        #expect(presentation.retry?.help == "Try to register ⌥Space again")
        #expect(presentation.statusIconIsDecorative)
        #expect(!presentation.title.contains("9878"))
        #expect(!presentation.help.contains("9878"))
    }

    @Test("generic registration failures do not claim another app owns the shortcut")
    func registrationFailureStatusPresentation() {
        let presentation = HotkeyManager.statusPresentation(for: .registrationFailed)

        #expect(presentation.title == "Global hotkey unavailable")
        #expect(
            presentation.help
                == "herminal couldn't register ⌥Space. You can still use Window → Show Hotkey Window or Command Palette."
        )
        #expect(presentation.showsRetry)
        #expect(presentation.retry != nil)
        #expect(presentation.statusIconIsDecorative)
        #expect(!presentation.help.contains("-50"))
        #expect(!presentation.help.contains("Another app"))
    }

    @Test("registration status codes map to truthful availability states")
    func registrationStateMapping() {
        #expect(HotkeyManager.registrationState(for: noErr) == .registered)
        #expect(
            HotkeyManager.registrationState(for: OSStatus(eventHotKeyExistsErr))
                == .shortcutConflict
        )
        #expect(
            HotkeyManager.registrationState(for: OSStatus(paramErr))
                == .registrationFailed
        )
    }

    @Test("a successful status without a registered reference remains failed")
    func successfulStatusWithoutReference() {
        let driver = StubRegistrationDriver(attempts: [
            .init(status: noErr, producesReference: false),
        ])
        let manager = HotkeyManager(registrationDriver: driver)

        manager.install()

        #expect(manager.registrationState == .registrationFailed)
        #expect(driver.registrationCallCount == 1)
    }

    @Test("retry can recover a shortcut conflict")
    func retryAfterShortcutConflict() {
        let driver = StubRegistrationDriver(attempts: [
            .init(
                status: OSStatus(eventHotKeyExistsErr),
                producesReference: false
            ),
            .init(status: noErr, producesReference: true),
        ])
        let manager = HotkeyManager(registrationDriver: driver)

        manager.install()
        #expect(manager.registrationState == .shortcutConflict)

        manager.retryRegistration()

        #expect(manager.registrationState == .registered)
        #expect(driver.registrationCallCount == 2)
    }

    @Test("retry can recover a generic registration failure")
    func retryAfterGenericFailure() {
        let driver = StubRegistrationDriver(attempts: [
            .init(status: OSStatus(paramErr), producesReference: false),
            .init(status: noErr, producesReference: true),
        ])
        let manager = HotkeyManager(registrationDriver: driver)

        manager.install()
        #expect(manager.registrationState == .registrationFailed)

        manager.retryRegistration()

        #expect(manager.registrationState == .registered)
        #expect(driver.registrationCallCount == 2)
    }
}
