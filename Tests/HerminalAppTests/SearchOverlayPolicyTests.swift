import Combine
import Testing
@testable import HerminalApp

@Suite("Search overlay policy")
@MainActor
struct SearchOverlayPolicyTests {
    @Test("reopening search emits a fresh field-focus request every time")
    func repeatedFieldFocusRequests() {
        let state = SearchOverlayState()

        #expect(state.focusRequestRevision == 0)

        state.requestFieldFocus()
        #expect(state.focusRequestRevision == 1)

        state.requestFieldFocus()
        #expect(state.focusRequestRevision == 2)
    }

    @Test("changing the query clears stale match metadata immediately")
    func queryChangeClearsStaleMatchMetadata() {
        let state = SearchOverlayState()
        state.needle = "error"
        state.total = 7
        state.selected = 2

        state.needle = "warning"

        #expect(state.total == nil)
        #expect(state.selected == nil)
    }

    @Test("query metadata clears before subscribers receive the new needle")
    func queryMetadataClearsBeforeNeedlePublication() {
        let state = SearchOverlayState()
        state.needle = "error"
        state.total = 7
        state.selected = 2
        var metadataSeenBySubscriber: (total: Int?, selected: Int?)?
        let subscription = state.$needle.dropFirst().sink { _ in
            metadataSeenBySubscriber = (state.total, state.selected)
        }

        state.needle = "warning"

        #expect(metadataSeenBySubscriber?.total == nil)
        #expect(metadataSeenBySubscriber?.selected == nil)
        withExtendedLifetime(subscription) {}
    }

    @Test("same-pane overlay reuse requests field focus instead of rebuilding")
    func overlayReuseRequestsFieldFocus() {
        let state = SearchOverlayState()

        let reused = WorkspaceView.reuseExistingSearchOverlay(
            hasOverlay: true,
            sameTarget: true,
            state: state
        )

        #expect(reused)
        #expect(state.focusRequestRevision == 1)
    }

    @Test("different-pane or missing-overlay paths do not request reuse focus")
    func overlayReuseGuards() {
        let state = SearchOverlayState()

        #expect(
            !WorkspaceView.reuseExistingSearchOverlay(
                hasOverlay: false,
                sameTarget: true,
                state: state
            )
        )
        #expect(
            !WorkspaceView.reuseExistingSearchOverlay(
                hasOverlay: true,
                sameTarget: false,
                state: state
            )
        )
        #expect(
            !WorkspaceView.reuseExistingSearchOverlay(
                hasOverlay: true,
                sameTarget: true,
                state: nil
            )
        )
        #expect(state.focusRequestRevision == 0)
    }

    @Test("search requests initial focus after the hosting view can attach")
    func initialFocusSchedulingPolicy() async {
        var requestReturned = false

        await withCheckedContinuation { continuation in
            SearchOverlayView.requestInitialFocus {
                #expect(requestReturned)
                continuation.resume()
            }
            requestReturned = true
        }
    }

    @Test("search controls expose explicit VoiceOver copy and compact targets")
    func accessibilityCopy() {
        #expect(
            SearchOverlayView.searchFieldAccessibilityPresentation
                == .init(
                    label: "Search scrollback",
                    hint: "Type to search the current terminal scrollback"
                )
        )
        #expect(
            SearchOverlayView.previousMatchAccessibilityPresentation
                == .init(
                    label: "Previous match",
                    hint: "Press Command-Shift-G to move to the previous match"
                )
        )
        #expect(
            SearchOverlayView.nextMatchAccessibilityPresentation
                == .init(
                    label: "Next match",
                    hint: "Press Command-G or Return to move to the next match"
                )
        )
        #expect(
            SearchOverlayView.closeAccessibilityPresentation
                == .init(
                    label: "Close search",
                    hint: "Press Escape to dismiss the search overlay"
                )
        )
        #expect(
            SearchOverlayView.compactControlSize
                == HerminalDesign.Geometry.compactInteractiveControlSize
        )
        #expect(SearchOverlayView.escapeDismissalScope == .overlay)
    }

    @Test("empty needles hide match-count chrome and spoken status")
    func emptyNeedleHidesMatchCount() {
        #expect(
            SearchOverlayView.matchCountPresentation(
                needle: "",
                selected: nil,
                total: nil
            ) == .init(visibleText: nil, accessibilityLabel: nil)
        )
        #expect(
            SearchOverlayView.matchCountPresentation(
                needle: "",
                selected: 1,
                total: 4
            ) == .init(visibleText: nil, accessibilityLabel: nil)
        )
    }

    @Test("match count announces searching, totals, and current match contextually")
    func contextualMatchCountCopy() {
        #expect(
            SearchOverlayView.matchCountPresentation(
                needle: "error",
                selected: nil,
                total: nil
            ) == .init(visibleText: "…", accessibilityLabel: "Search in progress")
        )
        #expect(
            SearchOverlayView.matchCountPresentation(
                needle: "error",
                selected: nil,
                total: 0
            ) == .init(visibleText: "no matches", accessibilityLabel: "No matches")
        )
        #expect(
            SearchOverlayView.matchCountPresentation(
                needle: "error",
                selected: nil,
                total: 1
            ) == .init(visibleText: "1 match", accessibilityLabel: "1 match")
        )
        #expect(
            SearchOverlayView.matchCountPresentation(
                needle: "error",
                selected: nil,
                total: 7
            ) == .init(visibleText: "7 matches", accessibilityLabel: "7 matches")
        )
        #expect(
            SearchOverlayView.matchCountPresentation(
                needle: "error",
                selected: 2,
                total: 7
            ) == .init(visibleText: "3 / 7", accessibilityLabel: "Match 3 of 7")
        )
    }

    @Test("match navigation is available only when the query has results")
    func matchNavigationAvailability() {
        #expect(!SearchOverlayView.matchNavigationIsEnabled(needle: "", total: 3))
        #expect(!SearchOverlayView.matchNavigationIsEnabled(needle: "error", total: nil))
        #expect(!SearchOverlayView.matchNavigationIsEnabled(needle: "error", total: -1))
        #expect(!SearchOverlayView.matchNavigationIsEnabled(needle: "error", total: 0))
        #expect(SearchOverlayView.matchNavigationIsEnabled(needle: "error", total: 1))
        #expect(SearchOverlayView.matchNavigationIsEnabled(needle: "error", total: 7))
    }

    @Test("workspace search commands mirror the overlay navigation state")
    func workspaceSearchCommandAvailability() {
        let state = SearchOverlayState()
        state.needle = "error"
        state.total = 1

        #expect(!WorkspaceView.searchNavigationIsEnabled(hasOverlay: false, state: state))
        #expect(!WorkspaceView.searchNavigationIsEnabled(hasOverlay: true, state: nil))

        state.needle = ""
        state.total = 1
        #expect(!WorkspaceView.searchNavigationIsEnabled(hasOverlay: true, state: state))

        state.needle = "error"
        state.total = 1
        #expect(WorkspaceView.searchNavigationIsEnabled(hasOverlay: true, state: state))
    }

    @Test("invalid current-match indexes fall back to total-count copy")
    func outOfRangeSelectionFallsBackToCountCopy() {
        #expect(
            SearchOverlayView.matchCountPresentation(
                needle: "error",
                selected: -1,
                total: 7
            ) == .init(visibleText: "7 matches", accessibilityLabel: "7 matches")
        )
        #expect(
            SearchOverlayView.matchCountPresentation(
                needle: "error",
                selected: 7,
                total: 7
            ) == .init(visibleText: "7 matches", accessibilityLabel: "7 matches")
        )
    }
}
