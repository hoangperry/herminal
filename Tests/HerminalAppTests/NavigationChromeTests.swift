import AppKit
import Foundation
import Testing
@testable import HerminalApp

@Suite("Navigation chrome keyboard policy")
@MainActor
struct NavigationChromeKeyboardPolicyTests {
    @Test("tab-bar controls use the dense macOS target without overflowing the strip")
    func tabBarControlSizing() {
        #expect(
            TabBarView.compactInteractiveControlSize
                == HerminalDesign.Geometry.compactInteractiveControlSize
        )
        #expect(TabBarView.compactInteractiveControlSize <= TabBarView.barHeight)
    }

    @Test("keyboard focus lifts inactive tabs to full visual emphasis")
    func focusedTabsAreNeverDimmed() {
        #expect(TabBarView.shouldDimTab(
            isActive: false,
            isHovered: false,
            isSelectionFocused: false,
            isCloseFocused: false
        ))
        #expect(!TabBarView.shouldDimTab(
            isActive: false,
            isHovered: false,
            isSelectionFocused: true,
            isCloseFocused: false
        ))
        #expect(!TabBarView.shouldDimTab(
            isActive: false,
            isHovered: false,
            isSelectionFocused: false,
            isCloseFocused: true
        ))
        #expect(!TabBarView.shouldDimTab(
            isActive: true,
            isHovered: false,
            isSelectionFocused: false,
            isCloseFocused: false
        ))
    }

    @Test("tab-strip actions retain keyboard focus instead of reclaiming the terminal")
    func tabStripRefreshFocusPolicy() {
        let tabID = UUID()
        let selection = WorkspaceView.RefreshFocusPolicy.tabBar(.tab(tabID))
        let close = WorkspaceView.RefreshFocusPolicy.tabBar(.close(tabID))
        let newTab = WorkspaceView.RefreshFocusPolicy.tabBar(.newTab)

        #expect(!selection.focusesActivePane)
        #expect(selection.tabBarTarget == .tab(tabID))
        #expect(close.tabBarTarget == .close(tabID))
        #expect(newTab.tabBarTarget == .newTab)
        #expect(WorkspaceView.RefreshFocusPolicy.activePane.focusesActivePane)
        #expect(WorkspaceView.RefreshFocusPolicy.activePane.tabBarTarget == nil)
    }

    @Test("passive tab-bar rebuilds retain focus and ignore stale root callbacks")
    func passiveTabBarRebuildRetainsFocus() {
        let tabID = UUID()
        let target = TabBarView.FocusTarget.close(tabID)
        var retention = WorkspaceView.TabBarFocusRetention()

        let originalGeneration = retention.beginRebuild(requestedTarget: target)
        retention.focusDidChange(target, isFocused: true, generation: originalGeneration)
        let passiveGeneration = retention.beginRebuild()

        #expect(retention.target == target)
        retention.focusDidChange(target, isFocused: false, generation: originalGeneration)
        #expect(retention.target == target)

        retention.focusDidChange(target, isFocused: false, generation: passiveGeneration)
        #expect(retention.target == nil)
    }

    @Test("closing tabs preserves the logical active tab")
    func closingTabsPreservesLogicalSelection() {
        let firstID = UUID()
        let activeID = UUID()
        let lastID = UUID()

        #expect(WorkspaceView.activeTabIndexAfterClosing(
            closedIndex: 0,
            activeIndex: 2,
            remainingCount: 2
        ) == 1)
        #expect(WorkspaceView.activeTabIndexAfterClosing(
            closedIndex: 2,
            activeIndex: 0,
            remainingCount: 2
        ) == 0)
        #expect(WorkspaceView.activeTabIndexAfterClosing(
            closedIndex: 1,
            activeIndex: 1,
            remainingCount: 2
        ) == 1)
        #expect(WorkspaceView.activeTabIndexAfterClosing(
            closedIndex: 2,
            activeIndex: 2,
            remainingCount: 2
        ) == 1)

        #expect(WorkspaceView.closeTabOutcome(
            closedIndex: 0,
            activeIndex: 2,
            remainingTabIDs: [firstID, activeID],
            retainTabBarFocus: true
        ) == .keepWorkspace(
            activeIndex: 1,
            focusPolicy: .tabBar(.tab(activeID))
        ))
        #expect(WorkspaceView.closeTabOutcome(
            closedIndex: 1,
            activeIndex: 1,
            remainingTabIDs: [firstID, lastID],
            retainTabBarFocus: false
        ) == .keepWorkspace(
            activeIndex: 1,
            focusPolicy: .activePane
        ))
        #expect(WorkspaceView.closeTabOutcome(
            closedIndex: 0,
            activeIndex: 0,
            remainingTabIDs: [],
            retainTabBarFocus: true
        ) == .closeWindow)
    }

    @Test("tab focus transitions honor Reduce Motion")
    func tabFocusTransitionsHonorReduceMotion() {
        #expect(TabBarView.shouldAnimateFocusTransition(reduceMotion: false))
        #expect(!TabBarView.shouldAnimateFocusTransition(reduceMotion: true))
    }

    @Test("active and inactive tabs expose stable selection semantics")
    func tabSelectionAccessibility() {
        let active = TabBarView.tabAccessibilityPresentation(
            title: "api-server",
            isActive: true
        )
        let inactive = TabBarView.tabAccessibilityPresentation(
            title: "worker",
            isActive: false
        )

        #expect(active.label == "Tab api-server")
        #expect(active.value == "Selected")
        #expect(active.hint == "Press Return or Space to select this tab")
        #expect(inactive.label == "Tab worker")
        #expect(inactive.value == nil)
        #expect(inactive.hint == active.hint)
    }

    @Test("tab actions expose task-focused VoiceOver copy")
    func tabActionAccessibility() {
        #expect(
            TabBarView.closeTabAccessibilityPresentation(title: "api-server")
                == .init(
                    label: "Close tab api-server",
                    hint: "Closes this terminal tab"
                )
        )
        #expect(
            TabBarView.newTabAccessibilityPresentation
                == .init(
                    label: "New tab",
                    hint: "Opens a new terminal tab"
                )
        )
    }

    @Test("visual truncation never shortens a tab's spoken title")
    func longTabTitleAccessibility() {
        let title = String(repeating: "非常に長い作業セッション-", count: 8)
        let presentation = TabBarView.tabAccessibilityPresentation(
            title: title,
            isActive: false
        )

        #expect(presentation.label == "Tab \(title)")
    }

    @Test("modal controls expose stable accessibility labels")
    func modalControlAccessibilityLabels() {
        #expect(ModalControlAccessibility.Labels.workspaceName == "Workspace name")
        #expect(ModalControlAccessibility.Labels.tmuxSessionName == "tmux session name")
        #expect(ModalControlAccessibility.Labels.tmuxSessionPicker == "Session to attach")
        #expect(
            ModalControlAccessibility.Labels.worktreeBranchName == "Worktree branch name"
        )
        #expect(ModalControlAccessibility.Labels.agentKind == "Agent kind")
    }

    @Test("modal helper labels popup controls and preserves initial responder")
    func modalControlAccessibilityPreparation() {
        let popup = NSPopUpButton()
        let alert = NSAlert()

        let prepared = ModalControlAccessibility.prepare(
            popup,
            label: ModalControlAccessibility.Labels.tmuxSessionPicker,
            initialResponderIn: alert
        )

        #expect(prepared === popup)
        #expect(prepared.accessibilityLabel() == ModalControlAccessibility.Labels.tmuxSessionPicker)
        #expect(alert.window.initialFirstResponder === popup)
    }
}
