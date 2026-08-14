// GitWorktree — FlightDeck's `wt` orchestrator, without tmux.
//
// Creates / lists / removes isolated git worktrees in a sibling
// `<repo>.worktrees/<slug>` directory so several agents can edit the
// same project on different branches without colliding. All git
// invocations go through `GitRunner` as argv arrays — never a shell
// string — so a hostile branch name cannot smuggle a second command.

import Foundation

enum GitWorktree {

    struct Entry: Equatable, Identifiable {
        let path: String
        let head: String?
        let branch: String?
        let isDetached: Bool

        var id: String { path }

        var label: String {
            if let branch { return branch }
            if isDetached { return "detached" }
            return (path as NSString).lastPathComponent
        }
    }

    struct Context: Equatable {
        let worktreeRoot: String
        let gitCommonDir: String
        let mainRepoRoot: String
    }

    enum ValidationError: Swift.Error, Equatable {
        case empty
        case tooLong
        case invalid
    }

    enum Error: Swift.Error, Equatable {
        case notARepo
        case gitFailed(String)
        case missingPath
        /// Destination already belongs to a different checkout.
        case pathBusy
    }

    private static let maxBranchLength = 200

    // MARK: - Pure helpers

    /// FlightDeck slug: flatten `/` and spaces, drop anything that is
    /// not alphanumeric / hyphen / underscore. Used only for the
    /// directory name; the git branch keeps its original spelling.
    static func slug(_ branch: String) -> String {
        let flattened = branch.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(flattened.unicodeScalars.filter { allowed.contains($0) })
    }

    /// Conservative git-ref subset. Rejects option-looking names,
    /// traversal, and the metacharacters git itself treats as magic.
    static func validateBranchName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.empty }
        guard trimmed.count <= maxBranchLength else { throw ValidationError.tooLong }
        guard !trimmed.hasPrefix("-"),
              !trimmed.hasPrefix("."),
              !trimmed.hasSuffix("."),
              !trimmed.hasSuffix(".lock"),
              !trimmed.contains(".."),
              !trimmed.contains("//"),
              !trimmed.contains("@{"),
              !trimmed.contains(" "),
              trimmed.allSatisfy({ ch in
                  ch.isLetter || ch.isNumber || ch == "/" || ch == "-"
                      || ch == "_" || ch == "."
              })
        else { throw ValidationError.invalid }
    }

    static func worktreePath(mainRepoRoot: String, branch: String) -> String {
        let root = standardized(mainRepoRoot)
        let parent = (root as NSString).deletingLastPathComponent
        let repo = (root as NSString).lastPathComponent
        let folder = (parent as NSString).appendingPathComponent("\(repo).worktrees")
        return standardized((folder as NSString).appendingPathComponent(slug(branch)))
    }

    static func mainRepoRoot(fromGitCommonDir commonDir: String) -> String? {
        var dir = standardized(commonDir)
        if dir.hasSuffix("/") { dir.removeLast() }
        guard dir.hasSuffix("/.git") else { return nil }
        return (dir as NSString).deletingLastPathComponent
    }

    static func standardized(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    static func pathsEqual(_ a: String?, _ b: String?) -> Bool {
        guard let a, let b else { return false }
        return standardized(a) == standardized(b)
    }

    static func parseGitDirFile(_ contents: String) -> String? {
        let line = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("gitdir:") else { return nil }
        let rest = line.dropFirst("gitdir:".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.isEmpty ? nil : rest
    }

    static func parsePorcelain(_ text: String) -> [Entry] {
        var entries: [Entry] = []
        var path: String?
        var head: String?
        var branch: String?
        var detached = false

        func flush() {
            guard let path else { return }
            entries.append(Entry(
                path: standardized(path), head: head, branch: branch, isDetached: detached
            ))
        }

        for raw in text.split(whereSeparator: \.isNewline) {
            let line = String(raw)
            if line.hasPrefix("worktree ") {
                flush()
                path = String(line.dropFirst("worktree ".count))
                head = nil
                branch = nil
                detached = false
            } else if line.hasPrefix("HEAD ") {
                head = String(line.dropFirst("HEAD ".count))
            } else if line.hasPrefix("branch ") {
                let ref = String(line.dropFirst("branch ".count))
                branch = ref.hasPrefix("refs/heads/")
                    ? String(ref.dropFirst("refs/heads/".count))
                    : ref
            } else if line == "detached" {
                detached = true
                branch = nil
            }
        }
        flush()
        return entries
    }

    // MARK: - Process-backed

    static func resolveContext(cwd: String, runner: GitRunner = .live) throws -> Context {
        let top = runner.run(["rev-parse", "--show-toplevel"], in: cwd)
        let common = runner.run(["rev-parse", "--git-common-dir"], in: cwd)
        guard top.status == 0, common.status == 0 else { throw Error.notARepo }
        let worktreeRoot = absolutize(top.stdout, base: cwd)
        let gitCommonDir = absolutize(common.stdout, base: worktreeRoot)
        guard !worktreeRoot.isEmpty, !gitCommonDir.isEmpty,
              let main = mainRepoRoot(fromGitCommonDir: gitCommonDir)
        else { throw Error.notARepo }
        return Context(
            worktreeRoot: worktreeRoot,
            gitCommonDir: gitCommonDir,
            mainRepoRoot: main
        )
    }

    /// `rev-parse --git-common-dir` often prints `.git`; join it onto the
    /// worktree root so `mainRepoRoot` can see the `/…/.git` suffix.
    private static func absolutize(_ raw: String, base: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("/") { return (trimmed as NSString).standardizingPath }
        return ((base as NSString).appendingPathComponent(trimmed) as NSString).standardizingPath
    }

    static func list(cwd: String, runner: GitRunner = .live) throws -> [Entry] {
        let result = runner.run(["worktree", "list", "--porcelain"], in: cwd)
        guard result.status == 0 else { throw Error.notARepo }
        return parsePorcelain(result.stdout)
    }

    /// Creates the sibling worktree (or reuses it) and returns its path.
    @discardableResult
    static func add(branch: String, cwd: String, runner: GitRunner = .live) throws -> String {
        try validateBranchName(branch)
        let ctx = try resolveContext(cwd: cwd, runner: runner)
        let path = worktreePath(mainRepoRoot: ctx.mainRepoRoot, branch: branch)
        let listed = (try? list(cwd: ctx.mainRepoRoot, runner: runner)) ?? []
        if let existing = listed.first(where: { pathsEqual($0.path, path) }) {
            if existing.branch == branch { return existing.path }
            throw Error.pathBusy
        }
        let parent = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: parent, withIntermediateDirectories: true
        )

        let exists = runner.run(
            ["show-ref", "--verify", "--quiet", "refs/heads/\(branch)"],
            in: ctx.mainRepoRoot
        )
        let args: [String]
        if exists.status == 0 {
            args = ["worktree", "add", "--", path, branch]
        } else {
            args = ["worktree", "add", "-b", branch, "--", path]
        }
        let result = runner.run(args, in: ctx.mainRepoRoot)
        guard result.status == 0 else {
            let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw Error.gitFailed(detail)
        }
        return path
    }

    /// Removes a linked worktree. Git is invoked from the worktree
    /// itself so the focused pane's cwd (which may be another repo)
    /// cannot redirect the delete.
    static func remove(path: String, cwd: String? = nil, runner: GitRunner = .live) throws {
        let abs = standardized(path)
        guard !abs.isEmpty, abs.hasPrefix("/") else { throw Error.missingPath }
        let gitCwd = cwd.map(standardized) ?? abs
        let result = runner.run(["worktree", "remove", "--", abs], in: gitCwd)
        guard result.status == 0 else {
            let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw Error.gitFailed(detail)
        }
    }
}

/// argv-only git runner. Tests swap this for a fake; production uses
/// `/usr/bin/git` so PATH hijacking cannot redirect the spawn.
struct GitRunner: Sendable {
    private let execute: @Sendable ([String], String) -> (status: Int32, stdout: String, stderr: String)

    init(_ execute: @escaping @Sendable ([String], String) -> (status: Int32, stdout: String, stderr: String)) {
        self.execute = execute
    }

    func run(_ args: [String], in cwd: String) -> (status: Int32, stdout: String, stderr: String) {
        execute(args, cwd)
    }

    static let live = GitRunner { args, cwd in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: cwd, isDirectory: true)
        process.standardInput = FileHandle.nullDevice
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
        } catch {
            return (127, "", error.localizedDescription)
        }
        let deadline = Date().addingTimeInterval(8)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.2)
            if process.isRunning { process.interrupt() }
            return (124, "", "git timed out")
        }
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, stdout, stderr)
    }
}
