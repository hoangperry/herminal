// CommandPalette — ⌘⇧P fuzzy launcher over the workspace.
//
// Same shape as Raycast / Linear / VS Code: a floating panel with a
// search field at top and a result list below. Each row is an
// `Action` that, when chosen, dispatches a selector up the responder
// chain — so the palette can fire ANY menu action without us
// re-implementing each handler.
//
// Why an NSPanel (not a SwiftUI sheet): we need the window to float
// above the terminal surface, accept first-responder for the search
// field, and dismiss on Esc / loss of focus. NSPanel.becomesKeyOnlyIfNeeded
// is the right primitive; a SwiftUI .sheet would block the terminal
// underneath instead of overlaying.

import AppKit
import SwiftUI

@MainActor
enum CommandPalette {
    private static var panel: NSPanel?

    /// Toggles the palette. Closing happens on Esc, loss of focus, or
    /// after an action runs.
    static func toggle() {
        if let existing = panel, existing.isVisible {
            close()
            return
        }
        show()
    }

    static func show() {
        // Always rebuild a fresh panel: reusing the cached one keeps its
        // SwiftUI @State (the typed query + selection cursor) across opens,
        // and `hidesOnDeactivate` orders the panel out without routing
        // through close(), so a stale needle would survive the next ⌘⇧P.
        // Tearing down + rebuilding guarantees an empty field every time
        // and frees the hosting view between opens. (v0.4.3 review MED.)
        close()
        let palette = makePanel()
        panel = palette

        // Centre over the current key window — falls back to screen
        // centre when no window has focus (e.g. the user hits the
        // shortcut from the menu bar).
        if let host = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.title == "herminal" }) {
            let hostFrame = host.frame
            let paletteSize = palette.frame.size
            let originX = hostFrame.midX - paletteSize.width / 2
            // Sit it 1/4 from the top so it doesn't cover the bottom
            // of the terminal — matches Spotlight / Raycast convention.
            let originY = hostFrame.maxY - paletteSize.height - hostFrame.height * 0.18
            palette.setFrameOrigin(NSPoint(x: originX, y: originY))
        } else {
            palette.center()
        }
        palette.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func close() {
        panel?.orderOut(nil)
        // Drop the strong ref so the panel + its SwiftUI hosting view
        // deallocate; show() rebuilds fresh. (isReleasedWhenClosed is
        // false, so nil-ing here is what actually releases it.)
        panel = nil
    }

    private static func makePanel() -> NSPanel {
        let actions = CommandPaletteCatalog.actions(from: NSApp.mainMenu)
        let panel = CommandPalettePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let host = NSHostingView(
            rootView: CommandPaletteView(
                actions: actions,
                onDismiss: { CommandPalette.close() }
            )
        )
        host.frame = panel.contentLayoutRect
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        return panel
    }
}

/// NSPanel subclass that accepts key + first-responder. The default
/// `.borderless` panel ignores key events, so the search field can't
/// receive focus without this override.
final class CommandPalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// The SwiftUI body. Owns the filter text, selection cursor, and
/// keyboard handling (↑↓ to move, Enter to fire, Esc to dismiss).
struct CommandPaletteView: View {
    struct SearchAccessibilityPresentation: Equatable {
        let label: String
        let hint: String
    }

    struct RowAccessibilityPresentation: Equatable {
        let label: String
        let value: String?
        let hint: String
        let isSelected: Bool
    }

    struct RowChromePresentation: Equatable {
        let isEmphasized: Bool
        let showsFocusStroke: Bool
    }

    enum EscapeDismissalScope: Equatable {
        case searchField
        case palette
    }

    static let escapeDismissalScope: EscapeDismissalScope = .palette
    static let searchAccessibilityPresentation = SearchAccessibilityPresentation(
        label: "Command search",
        hint: "Use the Up and Down Arrow keys to choose a command, then press Return to run it"
    )

    let actions: [CommandPaletteAction]
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFocused: Bool
    @FocusState private var focusedResultID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var filtered: [CommandPaletteAction] {
        Self.filteredActions(actions, query: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().background(HerminalDesign.Palette.border)
            resultList
        }
        .background(
            // Panel chrome: dark surface with a subtle inner glow. The
            // outer NSPanel shadow does the lift; this material gives
            // the rounded card feel.
            RoundedRectangle(cornerRadius: 12)
                .fill(HerminalDesign.Palette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(HerminalDesign.Palette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            focusedResultID = nil
            searchFocused = true
            selectedIndex = 0
        }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
        .onChange(of: focusedResultID) { _, resultID in
            guard let resultID,
                  let index = filtered.firstIndex(where: { $0.id == resultID }) else {
                return
            }
            selectedIndex = index
        }
        .onExitCommand(perform: onDismiss)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(HerminalDesign.Palette.textSecondary)
                .accessibilityHidden(true)
            TextField("Type a command…", text: $query)
                .font(.system(size: 15))
                .foregroundColor(HerminalDesign.Palette.textPrimary)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .accessibilityLabel(Self.searchAccessibilityPresentation.label)
                .accessibilityHint(Self.searchAccessibilityPresentation.hint)
                .onSubmit { fireSelected() }
                .onKeyPress(.upArrow) {
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.tab, phases: .down) { keyPress in
                    guard !keyPress.modifiers.contains(.shift),
                          let target = Self.resultFocusTarget(
                              actions: filtered,
                              selectedIndex: selectedIndex
                          ) else {
                        return .ignored
                    }
                    focusedResultID = target
                    return .handled
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var resultList: some View {
        if filtered.isEmpty {
            noResults
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, action in
                            CommandPaletteResultButton(
                                action: action,
                                accessibility: Self.rowAccessibilityPresentation(
                                    for: action,
                                    rowIndex: index,
                                    total: filtered.count,
                                    isSelected: index == selectedIndex
                                ),
                                isSelected: index == selectedIndex,
                                isFocused: focusedResultID == action.id,
                                onRun: { fire(action: action) }
                            )
                                .focused($focusedResultID, equals: action.id)
                                .id(action.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: selectedIndex) { _, newIndex in
                    guard filtered.indices.contains(newIndex) else { return }
                    if Self.shouldAnimateSelectionScroll(reduceMotion: reduceMotion) {
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(filtered[newIndex].id, anchor: .center)
                        }
                    } else {
                        proxy.scrollTo(filtered[newIndex].id, anchor: .center)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// Shown when the query matches nothing — without it the list area
    /// just went blank, reading as "broken" rather than "no match".
    private var noResults: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundColor(HerminalDesign.Palette.textTertiary)
                .accessibilityHidden(true)
            Text("No matching commands")
                .font(.system(size: 13))
                .foregroundColor(HerminalDesign.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }

    static func normalizedSelectionIndex(_ selectedIndex: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return min(max(selectedIndex, 0), total - 1)
    }

    static func resultPositionText(rowIndex: Int, total: Int) -> String? {
        guard total > 0, (0..<total).contains(rowIndex) else { return nil }
        return "\(rowIndex + 1) of \(total)"
    }

    static func resultFocusTarget(
        actions: [CommandPaletteAction],
        selectedIndex: Int
    ) -> String? {
        guard !actions.isEmpty else { return nil }
        let safeIndex = normalizedSelectionIndex(selectedIndex, total: actions.count)
        return actions[safeIndex].id
    }

    static func filteredActions(
        _ actions: [CommandPaletteAction],
        query: String
    ) -> [CommandPaletteAction] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return actions }

        return actions.filter { action in
            action.title.localizedCaseInsensitiveContains(needle)
                || action.subtitle?.localizedCaseInsensitiveContains(needle) == true
                || action.menuPath?.localizedCaseInsensitiveContains(needle) == true
                || action.menuTitle?.localizedCaseInsensitiveContains(needle) == true
                || action.shortcutDisplay?.localizedCaseInsensitiveContains(needle) == true
        }
    }

    static func rowAccessibilityPresentation(
        for action: CommandPaletteAction,
        rowIndex: Int,
        total: Int,
        isSelected: Bool
    ) -> RowAccessibilityPresentation {
        var valueParts: [String] = []
        if let subtitle = action.subtitle, !subtitle.isEmpty {
            valueParts.append(subtitle)
        }
        if let shortcut = action.shortcutDisplay, !shortcut.isEmpty {
            valueParts.append("Shortcut \(shortcut)")
        }
        if let position = resultPositionText(rowIndex: rowIndex, total: total) {
            valueParts.append(position)
        }
        return .init(
            label: action.title,
            value: valueParts.isEmpty ? nil : valueParts.joined(separator: ". "),
            hint: "Press Return or Space to run this command",
            isSelected: isSelected
        )
    }

    static func selectedResultAnnouncement(
        actions: [CommandPaletteAction],
        selectedIndex: Int
    ) -> String? {
        guard !actions.isEmpty else { return nil }
        let safeIndex = normalizedSelectionIndex(selectedIndex, total: actions.count)
        let presentation = rowAccessibilityPresentation(
            for: actions[safeIndex],
            rowIndex: safeIndex,
            total: actions.count,
            isSelected: true
        )
        return [presentation.label, presentation.value, "Selected"]
            .compactMap { $0 }
            .joined(separator: ". ")
    }

    static func selectionIndex(
        afterMoving selectedIndex: Int,
        by offset: Int,
        total: Int
    ) -> Int? {
        guard total > 0 else { return nil }
        let currentIndex = normalizedSelectionIndex(selectedIndex, total: total)
        let nextIndex = normalizedSelectionIndex(currentIndex + offset, total: total)
        return nextIndex == currentIndex ? nil : nextIndex
    }

    static func rowChromePresentation(
        isSelected: Bool,
        isHovered: Bool,
        isFocused: Bool
    ) -> RowChromePresentation {
        .init(
            isEmphasized: isSelected || isHovered || isFocused,
            showsFocusStroke: isFocused
        )
    }

    static func shouldAnimateSelectionScroll(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    private func moveSelection(by offset: Int) {
        guard let nextIndex = Self.selectionIndex(
            afterMoving: selectedIndex,
            by: offset,
            total: filtered.count
        ) else { return }
        selectedIndex = nextIndex
        guard let announcement = Self.selectedResultAnnouncement(
            actions: filtered,
            selectedIndex: selectedIndex
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

    private func fireSelected() {
        let safeIndex = Self.normalizedSelectionIndex(selectedIndex, total: filtered.count)
        guard filtered.indices.contains(safeIndex) else { return }
        selectedIndex = safeIndex
        fire(action: filtered[safeIndex])
    }

    private func fire(action: CommandPaletteAction) {
        onDismiss()
        // Defer so the panel closes before the action runs — keeps the
        // animation smooth and avoids the action targeting the
        // (closing) palette itself.
        DispatchQueue.main.async {
            NSApp.sendAction(action.selector, to: nil, from: nil)
        }
    }
}
