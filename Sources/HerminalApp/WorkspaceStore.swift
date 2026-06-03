// WorkspaceStore — persists the tab/pane/split layout so a relaunch
// picks up where the owner left off ("session restore"). Companion to
// WindowState (which only remembers frame + sidebar): this remembers
// the actual workspace content.
//
// Stored as JSON at ~/Library/Application Support/herminal/workspace.json
// rather than UserDefaults — it's a structured tree that can grow, and a
// human-readable file is easier to inspect / nuke than an opaque plist.
//
// Restore policy (deliberately conservative for v0.4.1):
//  - We restore the LAYOUT (tabs, split axis, pane ratios, focus) and
//    each pane's last working directory, spawning a PLAIN SHELL in each.
//  - We do NOT re-run ssh / claude / arbitrary commands. Those are
//    side-effectful (opening network connections, resuming an LLM
//    session) and surprising to fire on every launch. The cwd of an
//    ssh pane may also be a remote path — `load()` validates every cwd
//    against the local filesystem and drops it (→ home) if it doesn't
//    resolve, so a former ssh pane degrades to a clean local shell.

import Foundation

/// One pane within a restored tab. Only the working directory survives;
/// the command is intentionally not replayed (see file header).
struct PaneSnapshot: Codable, Sendable, Equatable {
    /// Last-known working directory (OSC 7). nil → spawn at the shell's
    /// default (home). Validated on load.
    var cwd: String?
}

/// One tab: its split geometry + the panes inside it.
struct TabSnapshot: Codable, Sendable, Equatable {
    var isVerticalSplit: Bool
    var focusedPaneIndex: Int
    /// Fractional pane extents along the split axis (sums to ~1.0).
    var paneRatios: [Double]
    var panes: [PaneSnapshot]
}

/// The whole workspace at quit time.
struct WorkspaceSnapshot: Codable, Sendable, Equatable {
    var tabs: [TabSnapshot]
    var activeTabIndex: Int
}

enum WorkspaceStore {
    private static var fileURL: URL {
        let fm = FileManager.default
        let dir = (try? fm.url(for: .applicationSupportDirectory,
                               in: .userDomainMask,
                               appropriateFor: nil, create: true))?
            .appendingPathComponent("herminal", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("workspace.json")
    }

    static func save(_ snapshot: WorkspaceSnapshot) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("herminal: workspace snapshot save failed: \(error)")
        }
    }

    /// Loads and sanitises the snapshot. Returns nil when there's nothing
    /// usable to restore (no file, empty, or every tab pruned away).
    static func load() -> WorkspaceSnapshot? {
        guard let data = try? Data(contentsOf: fileURL),
              let raw = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data) else {
            return nil
        }
        return sanitise(raw)
    }

    /// Clears the saved snapshot — used when restore is disabled so a
    /// stale file doesn't linger.
    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Drops empty tabs, repairs out-of-range indices, validates each
    /// pane's cwd against the local filesystem (stale / remote dirs →
    /// nil so the shell opens at home), and renormalises ratios.
    static func sanitise(_ snapshot: WorkspaceSnapshot) -> WorkspaceSnapshot? {
        let fm = FileManager.default
        let tabs: [TabSnapshot] = snapshot.tabs.compactMap { tab in
            guard !tab.panes.isEmpty else { return nil }
            let panes = tab.panes.map { pane -> PaneSnapshot in
                guard let cwd = pane.cwd else { return PaneSnapshot(cwd: nil) }
                var isDir: ObjCBool = false
                let exists = fm.fileExists(atPath: cwd, isDirectory: &isDir)
                return PaneSnapshot(cwd: (exists && isDir.boolValue) ? cwd : nil)
            }
            // Ratios must match pane count; fall back to even if not.
            // `$0 > 0` already rejects NaN and -∞; `isFinite` also rejects
            // +∞, so a corrupt JSON ratio can never reach the layout math.
            let ratios: [Double]
            if tab.paneRatios.count == panes.count,
               tab.paneRatios.allSatisfy({ $0 > 0 && $0.isFinite }) {
                let sum = tab.paneRatios.reduce(0, +)
                ratios = sum > 0 ? tab.paneRatios.map { $0 / sum }
                                 : Array(repeating: 1.0 / Double(panes.count), count: panes.count)
            } else {
                ratios = Array(repeating: 1.0 / Double(panes.count), count: panes.count)
            }
            let focus = min(max(tab.focusedPaneIndex, 0), panes.count - 1)
            return TabSnapshot(
                isVerticalSplit: tab.isVerticalSplit,
                focusedPaneIndex: focus,
                paneRatios: ratios,
                panes: panes
            )
        }
        guard !tabs.isEmpty else { return nil }
        let active = min(max(snapshot.activeTabIndex, 0), tabs.count - 1)
        return WorkspaceSnapshot(tabs: tabs, activeTabIndex: active)
    }
}
