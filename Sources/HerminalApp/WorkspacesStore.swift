// WorkspacesStore — named, saved layouts ("workspaces") the owner can
// re-open on demand. Distinct from WorkspaceStore (singular), which
// auto-saves the LAST session for restore-on-launch. This one is the
// explicit "Save Workspace As… / Open Workspace" library, à la iTerm2's
// window arrangements.
//
// A named workspace is just a label + the same WorkspaceSnapshot the
// session-restore path already produces — so opening one reuses
// WorkspaceView.restoreWorkspace verbatim. Stored as a JSON array at
// ~/Library/Application Support/herminal/workspaces.json.
//
// Same conservative restore policy as WorkspaceStore: layout + cwd come
// back as plain shells; commands (ssh / claude) are not replayed.

import Foundation

/// A saved layout the owner named.
struct NamedWorkspace: Codable, Sendable, Equatable, Identifiable {
    var name: String
    var snapshot: WorkspaceSnapshot
    /// Stable identity for SwiftUI/menu plumbing — the name is the key
    /// (save dedupes by name), so it doubles as the id.
    var id: String { name }
}

enum WorkspacesStore {
    private static var fileURL: URL {
        let fm = FileManager.default
        let dir = (try? fm.url(for: .applicationSupportDirectory,
                               in: .userDomainMask,
                               appropriateFor: nil, create: true))?
            .appendingPathComponent("herminal", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("workspaces.json")
    }

    /// All saved workspaces, sorted by name (stable menu order).
    static func all() -> [NamedWorkspace] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        // Reject a pathologically deep tree before the recursive Codable
        // decode can overflow the stack — same guard as WorkspaceStore,
        // since this file is equally user-editable (v0.5 security review).
        guard !JSONDepthGuard.exceedsMaxDepth(data) else {
            NSLog("herminal: workspaces.json exceeds max nesting depth — ignoring")
            return []
        }
        guard let list = try? JSONDecoder().decode([NamedWorkspace].self, from: data) else {
            return []
        }
        return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Saves (or overwrites by name) a workspace. Trims the name; a blank
    /// name is rejected (returns false). The name is also rejected if it
    /// carries a path separator or NUL — today it's only a JSON value, but
    /// guarding here keeps it safe to use as a filename component later
    /// (defense-in-depth; flagged in the v0.4.3 security review).
    @discardableResult
    static func save(name rawName: String, snapshot: WorkspaceSnapshot) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains("/"), !name.contains("\0") else { return false }
        var list = all().filter { $0.name != name }
        list.append(NamedWorkspace(name: name, snapshot: snapshot))
        write(list)
        return true
    }

    static func delete(name: String) {
        write(all().filter { $0.name != name })
    }

    static func workspace(named name: String) -> NamedWorkspace? {
        // Run the saved snapshot through the same sanitiser the launch
        // restore path uses, so a named workspace gets cwd validation +
        // index clamping + tree validation too (v0.5 review — the named
        // path previously bypassed it). nil if nothing usable survives.
        guard let found = all().first(where: { $0.name == name }),
              let clean = WorkspaceStore.sanitise(found.snapshot) else { return nil }
        return NamedWorkspace(name: found.name, snapshot: clean)
    }

    private static func write(_ list: [NamedWorkspace]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(list).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("herminal: workspaces save failed: \(error)")
        }
    }
}
