// GitInfo — best-effort current-branch lookup for a working directory,
// so the status bar can show `~/proj · main`. Deliberately tiny: it reads
// `.git/HEAD` directly rather than shelling out to `git`, and only runs
// when the shell reports a new cwd (OSC 7) — not on a timer — so it's a
// bounded handful of stats + one small file read per `cd`, never a hot
// loop. Returns nil for non-repos (degrades to just the path).
//
// Linked worktrees use a `.git` *file* (`gitdir: …`); we follow that
// pointer and read HEAD from the linked gitdir. `parseHead` is pure so
// it unit-tests without a real repo; the walk is FileManager-injectable.

import Foundation

enum GitInfo {
    private static let refPrefix = "ref: refs/heads/"
    /// Bound the upward walk so a cwd deep under `/` can't turn into an
    /// unbounded stat storm.
    private static let maxDepth = 32

    /// Walks up from `directory` looking for a `.git` directory *or* a
    /// `.git` file (linked worktree / submodule pointer) and returns the
    /// checked-out branch (or "detached" for a bare-SHA HEAD).
    /// nil when `directory` isn't inside a git repo.
    static func branch(forDirectory directory: String,
                       fileManager: FileManager = .default) -> String? {
        var dir = (directory as NSString).standardizingPath
        for _ in 0..<maxDepth {
            let gitPath = (dir as NSString).appendingPathComponent(".git")
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: gitPath, isDirectory: &isDir) {
                let headPath: String
                if isDir.boolValue {
                    headPath = (gitPath as NSString).appendingPathComponent("HEAD")
                } else {
                    guard let pointer = try? String(contentsOfFile: gitPath, encoding: .utf8),
                          let gitDir = GitWorktree.parseGitDirFile(pointer) else {
                        return nil
                    }
                    let resolved = gitDir.hasPrefix("/")
                        ? gitDir
                        : ((dir as NSString).appendingPathComponent(gitDir) as NSString).standardizingPath
                    headPath = (resolved as NSString).appendingPathComponent("HEAD")
                }
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
