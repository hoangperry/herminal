import Foundation
import Testing

@testable import HerminalApp

@Suite("Manual update check")
struct ManualUpdateCheckTests {
    @Test("release destination is the official HTTPS latest-release page")
    func officialReleaseDestination() {
        let destination = Updater.latestReleaseURL

        #expect(destination.scheme == "https")
        #expect(destination.host == "github.com")
        #expect(destination.path == "/hoangperry/herminal/releases/latest")
        #expect(destination.query == nil)
        #expect(destination.fragment == nil)
        #expect(
            Updater.latestReleaseLocationDescription
                == "github.com/hoangperry/herminal/releases/latest"
        )
    }

    @Test("manual check reports success and opens exactly once")
    func successfulOpen() {
        var destinations: [URL] = []

        let outcome = Updater.openLatestRelease { destination in
            destinations.append(destination)
            return true
        }

        #expect(outcome == .opened)
        #expect(destinations == [Updater.latestReleaseURL])
    }

    @Test("manual check reports failure without retrying")
    func failedOpen() {
        var attemptCount = 0

        let outcome = Updater.openLatestRelease { _ in
            attemptCount += 1
            return false
        }

        #expect(outcome == .failed)
        #expect(attemptCount == 1)
    }

    @Test("failure alert copy stays manual and points at the official release page")
    func failureAlertPresentation() {
        let presentation = Updater.manualUpdateFailureAlert

        #expect(presentation.messageText == "Couldn’t Open the Release Page")
        #expect(
            presentation.informativeText
                == "Visit github.com/hoangperry/herminal/releases/latest in your browser to check for a newer version."
        )
        #expect(presentation.buttonTitle == "OK")
        #expect(!presentation.informativeText.lowercased().contains("sparkle"))
        #expect(!presentation.informativeText.lowercased().contains("automatic"))
    }
}
