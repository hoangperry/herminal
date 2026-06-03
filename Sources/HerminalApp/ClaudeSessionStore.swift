// ClaudeSessionStore — reads Claude Code's own session transcripts so
// herminal can surface "resume this conversation" without the user
// hunting through ~/.claude.
//
// Claude Code persists every session at
//   ~/.claude/projects/<slug>/<sessionId>.jsonl
// where <slug> is the project's absolute cwd with `/` → `-`. The slug
// is LOSSY — a real path component containing a hyphen (e.g.
// `andromeda-next`) is indistinguishable from a `/` boundary — so we
// never decode it. Instead we read the real `cwd` out of the transcript
// body (every content line carries it). We only read the first ~16 KB
// of the newest transcript per project, so a multi-hundred-MB session
// file costs a couple of syscalls, not a full parse.
//
// Read-only. herminal never writes into ~/.claude.

import Foundation

/// One resumable Claude Code project, summarised from its newest
/// transcript. `Sendable` so it can ride a notification / cross an
/// isolation boundary into the SwiftUI panel.
public struct ClaudeProjectSession: Identifiable, Sendable, Equatable {
    public var id: String { sessionId }
    /// Filename stem of the newest transcript — the value to pass to
    /// `claude --resume`.
    public let sessionId: String
    /// Real working directory, parsed from the transcript body.
    public let cwd: String
    /// Last `git` branch Claude recorded, if any.
    public let gitBranch: String?
    /// Newest transcript's mtime — "last active".
    public let lastActive: Date
    /// How many transcripts (distinct sessions) this project has.
    public let sessionCount: Int

    /// Last path component of `cwd` — the human-facing project name.
    public var projectName: String {
        (cwd as NSString).lastPathComponent
    }
}

// Not @MainActor: this is pure read-only file I/O (FileManager +
// JSONSerialization) and touches no main-actor state, so it's safe to
// call from a background task. refreshClaudePanel offloads the scan off
// the main thread precisely because of that (v0.4.3 review HIGH-4).
public enum ClaudeSessionStore {
    /// `~/.claude/projects`. Resolved fresh each call so a HOME change
    /// in tests is honoured.
    private static var projectsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
    }

    /// Only read this many bytes from the head of a transcript when
    /// hunting for the `cwd` line — it appears within the first event.
    private static let headByteBudget = 16 * 1024

    /// Returns up to `limit` projects, most-recently-active first.
    /// Cheap enough to call on every sidebar open (one `stat` per
    /// project + a 16 KB read of one file per project).
    public static func recentProjects(limit: Int = 30) -> [ClaudeProjectSession] {
        let fm = FileManager.default
        guard let projectDirs = try? fm.contentsOfDirectory(
            at: projectsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let sessions = projectDirs.compactMap { summarise(projectDir: $0) }
        return sessions
            .sorted { $0.lastActive > $1.lastActive }
            .prefix(limit)
            .map { $0 }
    }

    /// Summarises one `~/.claude/projects/<slug>` directory by reading
    /// its newest transcript. Returns nil for empty / unreadable dirs.
    private static func summarise(projectDir: URL) -> ClaudeProjectSession? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: projectDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let transcripts = files.filter { $0.pathExtension == "jsonl" }
        guard !transcripts.isEmpty else { return nil }

        // Newest by mtime.
        let dated: [(URL, Date)] = transcripts.map { url in
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return (url, mod)
        }
        guard let newest = dated.max(by: { $0.1 < $1.1 }) else { return nil }

        let (cwd, gitBranch) = parseCwdAndBranch(from: newest.0)
        // No cwd in the body → can't safely resume (slug decode is
        // lossy). Skip rather than guess.
        guard let cwd else { return nil }

        // SECURITY (v0.4.3): the session id is the transcript filename
        // stem and it gets interpolated into the `claude --resume <id>`
        // command, which libghostty runs via the shell. A local process
        // can write any filename into ~/.claude/projects/*/, so a stem
        // like `x; rm -rf ~ #` would be a command-injection vector when
        // the user clicks Resume. Claude Code always names transcripts
        // with a UUID — reject anything that isn't one, so a crafted
        // filename can never reach the shell.
        let sessionId = newest.0.deletingPathExtension().lastPathComponent
        guard Self.isValidSessionID(sessionId) else { return nil }

        return ClaudeProjectSession(
            sessionId: sessionId,
            cwd: cwd,
            gitBranch: gitBranch,
            lastActive: newest.1,
            sessionCount: transcripts.count
        )
    }

    /// A Claude Code session id is a canonical UUID — the only shape
    /// Claude Code ever writes. `UUID(uuidString:)` enforces the exact
    /// `8-4-4-4-12` hex layout, so a planted filename (anything carrying
    /// shell metacharacters, or merely the wrong shape) can never reach
    /// the `claude --resume <id>` command string. (v0.4.3 review.)
    static func isValidSessionID(_ id: String) -> Bool {
        UUID(uuidString: id) != nil
    }

    /// Reads the head of a transcript and pulls the first `cwd` (and
    /// `gitBranch`, if present) out of the JSONL event stream.
    private static func parseCwdAndBranch(from file: URL) -> (cwd: String?, branch: String?) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return (nil, nil) }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: headByteBudget),
              let text = String(data: data, encoding: .utf8) else { return (nil, nil) }

        // The last newline may bisect a JSON object; drop the trailing
        // partial line so JSONSerialization doesn't choke on it.
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        if !text.hasSuffix("\n"), !lines.isEmpty { lines.removeLast() }

        for line in lines {
            guard line.contains("\"cwd\""),
                  let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let cwd = obj["cwd"] as? String, !cwd.isEmpty
            else { continue }
            let branch = (obj["gitBranch"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return (cwd, branch)
        }
        return (nil, nil)
    }
}
