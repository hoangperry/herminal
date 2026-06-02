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
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([NamedWorkspace].self, from: data) else {
            return []
        }
        return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Saves (or overwrites by name) a workspace. Trims the name; a blank
    /// name is rejected (returns false).
    @discardableResult
    static func save(name rawName: String, snapshot: WorkspaceSnapshot) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        var list = all().filter { $0.name != name }
        list.append(NamedWorkspace(name: name, snapshot: snapshot))
        write(list)
        return true
    }

    static func delete(name: String) {
        write(all().filter { $0.name != name })
    }

    static func workspace(named name: String) -> NamedWorkspace? {
        all().first { $0.name == name }
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
