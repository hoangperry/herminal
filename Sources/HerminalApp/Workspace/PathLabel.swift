// PathLabel — pure helpers that turn an absolute working directory into
// a human-facing label. `~` for home, a compact basename for tab strips.
// Kept dependency-free + injectable-home so it unit-tests without
// touching the real filesystem. (v0.4.4 live-cwd surfacing.)

import Foundation

enum PathLabel {
    /// Replaces the home-directory prefix with `~`; leaves other paths
    /// untouched. `/Users/me/proj` → `~/proj`, `/Users/me` → `~`,
    /// `/etc` → `/etc`.
    static func abbreviateHome(_ path: String, home: String = NSHomeDirectory()) -> String {
        guard !home.isEmpty else { return path }
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    /// A compact tab label: `~` for home, otherwise the last path
    /// component. `/Users/me/pet/herminal` → `herminal`, `/` → `/`,
    /// a trailing slash is ignored (`/a/b/` → `b`).
    static func tabLabel(for path: String, home: String = NSHomeDirectory()) -> String {
        if path == home { return "~" }
        let trimmed = (path.count > 1 && path.hasSuffix("/")) ? String(path.dropLast()) : path
        let last = (trimmed as NSString).lastPathComponent
        return last.isEmpty ? trimmed : last
    }
}
