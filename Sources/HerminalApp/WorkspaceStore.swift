// WorkspaceStore — persists the tab/pane/split layout so a relaunch
// picks up where the owner left off ("session restore"). Companion to
// WindowState (which only remembers frame + sidebar): this remembers
// the actual workspace content.
//
// Stored as JSON at ~/Library/Application Support/herminal/workspace.json
// rather than UserDefaults — it's a structured tree that can grow, and a
// human-readable file is easier to inspect / nuke than an opaque plist.
//
// Restore policy (deliberately conservative since v0.4.1):
//  - We restore the LAYOUT (the split tree + per-pane working directory),
//    spawning a PLAIN SHELL in each pane.
//  - We do NOT re-run ssh / claude / arbitrary commands. Those are
//    side-effectful (opening network connections, resuming an LLM
//    session) and surprising to fire on every launch. The cwd of an
//    ssh pane may also be a remote path — `load()` validates every cwd
//    against the local filesystem and drops it (→ home) if it doesn't
//    resolve, so a former ssh pane degrades to a clean local shell.
//
// Format note (v0.5): the layout is now a binary split TREE
// (`LayoutSnapshot`). Pre-v0.5 files were flat (a single axis +
// `paneRatios`); those fields are kept optional so old `workspace.json`
// still loads — `WorkspaceTab.init(restoring:)` rebuilds a flat tree from
// them when `layout` is absent.

import Foundation

/// One pane within a restored tab. Only the working directory survives;
/// the command is intentionally not replayed (see file header).
struct PaneSnapshot: Codable, Sendable, Equatable {
    /// Last-known working directory (OSC 7). nil → spawn at the shell's
    /// default (home). Validated on load.
    var cwd: String?
}

/// Serialized split tree. Leaves reference panes by INDEX into
/// `TabSnapshot.panes` — restore builds fresh sessions, so there's no
/// stable id to carry across launches. (Swift auto-synthesizes Codable
/// for this enum.)
indirect enum LayoutSnapshot: Codable, Sendable, Equatable {
    case leaf(Int)
    case split(axis: SplitAxis, ratio: Double, first: LayoutSnapshot, second: LayoutSnapshot)

    /// Every leaf index in the tree, in-order.
    func leafIndices() -> [Int] {
        switch self {
        case let .leaf(i): return [i]
        case let .split(_, _, first, second): return first.leafIndices() + second.leafIndices()
        }
    }
}

/// One tab: its panes + the split tree binding them together.
struct TabSnapshot: Codable, Sendable, Equatable {
    var panes: [PaneSnapshot]
    var focusedPaneIndex: Int
    /// The split tree (v0.5+). nil in pre-v0.5 files — those are flat and
    /// rebuilt from the legacy axis + ratios below.
    var layout: LayoutSnapshot?
    // Pre-v0.5 flat layout — optional so old workspace.json still decodes.
    var isVerticalSplit: Bool?
    var paneRatios: [Double]?
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
    /// nil so the shell opens at home), and drops a layout tree that
    /// doesn't reference exactly the surviving panes (→ flat fallback).
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
            // A layout tree only survives if its leaves are exactly the
            // panes 0..<count (each referenced once) — otherwise it can't
            // be rebuilt safely, so drop it and let restore fall back to a
            // flat even split.
            let layout: LayoutSnapshot? = {
                guard let tree = tab.layout else { return nil }
                let indices = tree.leafIndices().sorted()
                return indices == Array(0..<panes.count) ? tree : nil
            }()
            // Legacy flat fields (only used when `layout` is nil) — keep a
            // ratio array that matches the pane count, else drop to even.
            let legacyRatios: [Double]? = {
                guard let r = tab.paneRatios, r.count == panes.count,
                      r.allSatisfy({ $0 > 0 && $0.isFinite }) else { return nil }
                return r
            }()
            let focus = min(max(tab.focusedPaneIndex, 0), panes.count - 1)
            return TabSnapshot(
                panes: panes,
                focusedPaneIndex: focus,
                layout: layout,
                isVerticalSplit: tab.isVerticalSplit,
                paneRatios: legacyRatios
            )
        }
        guard !tabs.isEmpty else { return nil }
        let active = min(max(snapshot.activeTabIndex, 0), tabs.count - 1)
        return WorkspaceSnapshot(tabs: tabs, activeTabIndex: active)
    }
}
