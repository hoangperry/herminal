// KeyboardShortcutsWindow — searchable reference generated from the live
// macOS menu tree. Menu key equivalents remain the source of truth, so this
// help surface cannot silently drift from the shortcuts the app handles.

import AppKit
import SwiftUI

struct KeyboardShortcutEntry: Identifiable, Equatable {
    let id: String
    let title: String
    let menuPath: String
    let shortcut: String
}

struct KeyboardShortcutGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let entries: [KeyboardShortcutEntry]
}

@MainActor
enum KeyboardShortcutReference {
    static func groups(from mainMenu: NSMenu) -> [KeyboardShortcutGroup] {
        mainMenu.items.enumerated().compactMap { groupIndex, topLevelItem in
            guard let submenu = topLevelItem.submenu else { return nil }
            let title = submenu.title.isEmpty ? topLevelItem.title : submenu.title
            let entries = entries(
                in: submenu,
                rootTitle: title,
                parentTitles: [],
                indexPath: [groupIndex]
            )
            guard !entries.isEmpty else { return nil }
            return KeyboardShortcutGroup(
                id: "menu-\(groupIndex)-\(stableComponent(title))",
                title: title,
                entries: entries
            )
        }
    }

    static func filtered(
        _ groups: [KeyboardShortcutGroup],
        query: String
    ) -> [KeyboardShortcutGroup] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return groups }

        return groups.compactMap { group in
            let matchesWholeGroup = group.title.localizedCaseInsensitiveContains(needle)
            let entries = matchesWholeGroup
                ? group.entries
                : group.entries.filter { entry in
                    entry.title.localizedCaseInsensitiveContains(needle)
                        || entry.menuPath.localizedCaseInsensitiveContains(needle)
                        || entry.shortcut.localizedCaseInsensitiveContains(needle)
                }
            guard !entries.isEmpty else { return nil }
            return KeyboardShortcutGroup(id: group.id, title: group.title, entries: entries)
        }
    }

    static func displayShortcut(
        keyEquivalent: String,
        modifiers: NSEvent.ModifierFlags
    ) -> String {
        let modifierGlyphs: [(NSEvent.ModifierFlags, String)] = [
            (.control, "⌃"),
            (.option, "⌥"),
            (.shift, "⇧"),
            (.command, "⌘"),
        ]
        let prefix = modifierGlyphs.compactMap { flag, glyph in
            modifiers.contains(flag) ? glyph : nil
        }.joined()
        return prefix + displayKey(keyEquivalent)
    }

    private static func entries(
        in menu: NSMenu,
        rootTitle: String,
        parentTitles: [String],
        indexPath: [Int]
    ) -> [KeyboardShortcutEntry] {
        menu.items.enumerated().flatMap { itemIndex, item -> [KeyboardShortcutEntry] in
            let path = indexPath + [itemIndex]
            if let submenu = item.submenu {
                return entries(
                    in: submenu,
                    rootTitle: rootTitle,
                    parentTitles: parentTitles + [item.title],
                    indexPath: path
                )
            }
            guard !item.isSeparatorItem,
                  item.action != nil,
                  !item.keyEquivalent.isEmpty else {
                return []
            }
            let menuPath = ([rootTitle] + parentTitles).joined(separator: " › ")
            let selector = item.action.map(NSStringFromSelector) ?? "action"
            return [KeyboardShortcutEntry(
                id: "shortcut-\(path.map(String.init).joined(separator: "."))-\(stableComponent(selector))",
                title: item.title,
                menuPath: menuPath,
                shortcut: displayShortcut(
                    keyEquivalent: item.keyEquivalent,
                    modifiers: item.keyEquivalentModifierMask
                )
            )]
        }
    }

    private static func displayKey(_ keyEquivalent: String) -> String {
        switch keyEquivalent {
        case "\u{F700}": return "↑"
        case "\u{F701}": return "↓"
        case "\u{F702}": return "←"
        case "\u{F703}": return "→"
        case "\r", "\n": return "↩"
        case "\t": return "⇥"
        case "\u{1B}": return "Esc"
        case "\u{7F}": return "⌫"
        case " ": return "Space"
        default: return keyEquivalent.uppercased()
        }
    }

    private static func stableComponent(_ value: String) -> String {
        value.lowercased().map { character in
            character.isLetter || character.isNumber ? character : "-"
        }.reduce(into: "") { $0.append($1) }
    }
}

@MainActor
enum KeyboardShortcutsWindow {
    private static var window: NSWindow?
    private static var closeObserver: NSObjectProtocol?

    static func show(menu: NSMenu?) {
        guard let menu else {
            NSSound.beep()
            return
        }
        let groups = KeyboardShortcutReference.groups(from: menu)
        let hosting = NSHostingView(
            rootView: KeyboardShortcutsView(groups: groups, onClose: close)
        )

        if let existing = window {
            existing.contentView = hosting
            existing.appearance = HerminalDesign.nsAppearance
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let referenceWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        referenceWindow.title = "herminal — Keyboard Shortcuts"
        referenceWindow.contentView = hosting
        referenceWindow.appearance = HerminalDesign.nsAppearance
        referenceWindow.backgroundColor = NSColor(HerminalDesign.Palette.surfaceBase)
        referenceWindow.minSize = NSSize(width: 480, height: 360)
        referenceWindow.isReleasedWhenClosed = false
        referenceWindow.center()
        referenceWindow.makeKeyAndOrderFront(nil)
        window = referenceWindow

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: referenceWindow,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                window = nil
                if let closeObserver {
                    NotificationCenter.default.removeObserver(closeObserver)
                    self.closeObserver = nil
                }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    static func close() {
        window?.close()
    }
}

struct KeyboardShortcutsView: View {
    enum FocusTarget: Hashable {
        case search
    }

    struct AccessibilityPresentation: Equatable {
        let label: String
        let value: String
        let hint: String
    }

    static let initialFocusTarget: FocusTarget = .search

    let groups: [KeyboardShortcutGroup]
    let onClose: () -> Void

    @State private var query = ""
    @FocusState private var focusedTarget: FocusTarget?

    private var filteredGroups: [KeyboardShortcutGroup] {
        KeyboardShortcutReference.filtered(groups, query: query)
    }

    private var visibleShortcutCount: Int {
        filteredGroups.reduce(0) { $0 + $1.entries.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(HerminalDesign.Palette.divider)
            results
            Divider().background(HerminalDesign.Palette.divider)
            footer
        }
        .background(HerminalDesign.Palette.surfaceBase)
        .onAppear {
            DispatchQueue.main.async { focusedTarget = Self.initialFocusTarget }
        }
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.md) {
            VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xs) {
                Text("Keyboard Shortcuts")
                    .font(HerminalDesign.Typography.largeTitle)
                    .foregroundStyle(HerminalDesign.Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Generated from the current app menus, so the reference stays in sync.")
                    .font(HerminalDesign.Typography.body)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
            }
            TextField("Search actions, menus, or keys", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($focusedTarget, equals: .search)
                .accessibilityLabel("Search keyboard shortcuts")
                .accessibilityHint("Filters by action, menu, or key combination")
        }
        .padding(HerminalDesign.Spacing.xl)
    }

    @ViewBuilder
    private var results: some View {
        if filteredGroups.isEmpty {
            VStack(spacing: HerminalDesign.Spacing.sm) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 24))
                    .foregroundStyle(HerminalDesign.Palette.textTertiary)
                    .accessibilityHidden(true)
                Text("No shortcuts match “\(query)”")
                    .font(HerminalDesign.Typography.bodyEmphasis)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("No keyboard shortcuts match \(query)")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: HerminalDesign.Spacing.lg) {
                    ForEach(filteredGroups) { group in
                        shortcutGroup(group)
                    }
                }
                .padding(.horizontal, HerminalDesign.Spacing.xl)
                .padding(.vertical, HerminalDesign.Spacing.lg)
            }
        }
    }

    private func shortcutGroup(_ group: KeyboardShortcutGroup) -> some View {
        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xs) {
            Text(group.title.uppercased())
                .font(HerminalDesign.Typography.caption)
                .tracking(HerminalDesign.Typography.headerTracking)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityAddTraits(.isHeader)
            ForEach(group.entries) { entry in
                shortcutRow(entry)
            }
        }
    }

    private func shortcutRow(_ entry: KeyboardShortcutEntry) -> some View {
        let accessibility = Self.accessibilityPresentation(for: entry)
        return HStack(spacing: HerminalDesign.Spacing.md) {
            Text(entry.title)
                .font(HerminalDesign.Typography.body)
                .foregroundStyle(HerminalDesign.Palette.textPrimary)
            Spacer(minLength: HerminalDesign.Spacing.lg)
            Text(entry.shortcut)
                .font(HerminalDesign.Typography.monoCaption)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
                .padding(.horizontal, HerminalDesign.Spacing.sm)
                .padding(.vertical, HerminalDesign.Spacing.xs)
                .background(HerminalDesign.Palette.surfaceOverlay)
                .clipShape(RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm))
        }
        .padding(.vertical, HerminalDesign.Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility.label)
        .accessibilityValue(accessibility.value)
        .accessibilityHint(accessibility.hint)
    }

    private var footer: some View {
        HStack {
            Text("\(visibleShortcutCount) shortcut\(visibleShortcutCount == 1 ? "" : "s")")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityLabel("\(visibleShortcutCount) keyboard shortcut\(visibleShortcutCount == 1 ? "" : "s") shown")
            Spacer()
            Button("Close", action: onClose)
                .keyboardShortcut(.cancelAction)
                .accessibilityHint("Closes the keyboard shortcuts reference")
        }
        .padding(.horizontal, HerminalDesign.Spacing.xl)
        .padding(.vertical, HerminalDesign.Spacing.md)
    }

    static func accessibilityPresentation(
        for entry: KeyboardShortcutEntry
    ) -> AccessibilityPresentation {
        AccessibilityPresentation(
            label: entry.title,
            value: "Shortcut \(entry.shortcut)",
            hint: "\(entry.menuPath) menu command"
        )
    }
}
