// GitInfo — best-effort current-branch lookup for a working directory,
// so the status bar can show `~/proj · main`. Deliberately tiny: it reads
// `.git/HEAD` directly rather than shelling out to `git`, and only runs
// when the shell reports a new cwd (OSC 7) — not on a timer — so it's a
// bounded handful of stats + one small file read per `cd`, never a hot
// loop. Returns nil for non-repos (degrades to just the path).
//
// `parseHead` is pure so it unit-tests without a real repo; the walk is
// FileManager-injectable for the same reason.

import Foundation

enum GitInfo {
    private static let refPrefix = "ref: refs/heads/"
    /// Bound the upward walk so a cwd deep under `/` can't turn into an
    /// unbounded stat storm.
    private static let maxDepth = 32

    /// Walks up from `directory` looking for a `.git` directory and
    /// returns the checked-out branch (or "detached" for a bare-SHA HEAD).
    /// nil when `directory` isn't inside a git repo, or the repo uses a
    /// `.git` *file* (submodule / linked worktree) — which we don't follow.
    static func branch(forDirectory directory: String,
                       fileManager: FileManager = .default) -> String? {
        var dir = (directory as NSString).standardizingPath
        for _ in 0..<maxDepth {
            let gitPath = (dir as NSString).appendingPathComponent(".git")
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: gitPath, isDirectory: &isDir) {
                guard isDir.boolValue else { return nil } // .git file → skip
                let headPath = (gitPath as NSString).appendingPathComponent("HEAD")
                guard let head = try? String(contentsOfFile: headPath, encoding: .utf8) else {
                    return nil
                }
                return parseHead(head)
            }
            let parent = (dir as NSString).deletingLastPathComponent
            if parent == dir { break } // reached the filesystem root
            dir = parent
        }
        return nil
    }

    /// Parses `.git/HEAD`: `ref: refs/heads/<branch>` → "<branch>";
    /// a bare 40-hex object id → "detached"; anything else → nil.
    static func parseHead(_ contents: String) -> String? {
        let line = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix(refPrefix) {
            let branch = String(line.dropFirst(refPrefix.count))
            return branch.isEmpty ? nil : branch
        }
        if line.count >= 7, line.allSatisfy({ $0.isHexDigit }) {
            return "detached"
        }
        return nil
    }
}
