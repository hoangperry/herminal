// TmuxLaunch — PRD Must Feature 3 leftover: name + command builder
// for in-PTY tmux. List/has-session use a resolved absolute binary;
// the spawn string uses the basename `tmux` so the user's login PATH
// finds it. Never interpolates an unvalidated name.

import Darwin
import Foundation

enum TmuxLaunch {
    enum Action: Equatable, Sendable {
        case newSession
        case attach
        case attachOrCreate
    }

    enum ValidationError: Swift.Error, Equatable, Sendable {
        case empty
        case tooLong
        case invalid
    }

    enum Error: Swift.Error, Equatable, Sendable {
        case tmuxMissing
        case noWorkingDirectory
        case sessionExists
        case noSessions
        case invalidName
        case tmuxFailed(String)
    }

    struct Session: Equatable, Sendable, Identifiable {
        var id: String { name }
        let name: String
        let windows: Int
        let attachedClients: Int
    }

    static let maxNameLength = 64
    static let binaryCandidates = [
        "/opt/homebrew/bin/tmux",
        "/usr/local/bin/tmux",
        "/usr/bin/tmux",
    ]

    static func validateName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.empty }
        guard trimmed.count <= maxNameLength else { throw ValidationError.tooLong }
        guard !trimmed.hasPrefix("-"),
              !trimmed.contains(".."),
              !trimmed.contains(" "),
              !trimmed.contains("/"),
              trimmed.allSatisfy({ ch in
                  ch.isLetter || ch.isNumber || ch == "." || ch == "_" || ch == "-"
              })
        else { throw ValidationError.invalid }
    }

    static func slug(_ raw: String) -> String {
        let flattened = raw.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return String(flattened.unicodeScalars.filter { allowed.contains($0) })
    }

    static func sessionName(fromCwd cwd: String) -> String? {
        let base: String
        if let ctx = try? GitWorktree.resolveContext(cwd: cwd) {
            base = (ctx.mainRepoRoot as NSString).lastPathComponent
        } else {
            base = (cwd as NSString).lastPathComponent
        }
        let name = slug(base)
        guard (try? validateName(name)) != nil else { return nil }
        return name
    }

    static func resolveBinary(fileManager: FileManager = .default) -> String? {
        binaryCandidates.first { fileManager.isExecutableFile(atPath: $0) }
    }

    static func quote(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    static func command(action: Action, name: String) throws -> String {
        let name = try canonicalName(name)
        let quoted = quote(name)
        switch action {
        case .newSession:
            return "tmux new-session -s \(quoted)"
        case .attach:
            return "tmux attach-session -t \(quote("=\(name)"))"
        case .attachOrCreate:
            return "tmux new-session -A -s \(quoted)"
        }
    }

    static func parseSessionList(_ stdout: String) -> [String] {
        stdout.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// `list-sessions -F '#{session_name}\t#{session_windows}\t#{session_attached}'`
    static func parseSessionRecords(_ stdout: String) -> [Session] {
        stdout.split(whereSeparator: \.isNewline).compactMap { line in
            let raw = String(line)
            guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let parts = raw.split(separator: "\t", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            let name = parts.first ?? ""
            guard !name.isEmpty else { return nil }
            let windows = parts.count > 1 ? Int(parts[1]) ?? 1 : 1
            let attached = parts.count > 2 ? Int(parts[2]) ?? 0 : 0
            return Session(
                name: name,
                windows: max(windows, 0),
                attachedClients: max(attached, 0)
            )
        }
    }

    /// Names the dashboard and Attach… picker may show (and therefore attach/kill).
    static func displayableSessions(_ names: [String]) -> [String] {
        names.filter { (try? validateName($0)) != nil }
    }

    static func displayableSessions(_ sessions: [Session]) -> [Session] {
        sessions.filter { (try? validateName($0.name)) != nil }
    }

    /// Inverse of `command(action:name:)` for validated names (no quotes
    /// inside the name). Used to reuse an already-open attach tab.
    static func sessionName(fromSpawnCommand command: String) -> String? {
        let prefixes = [
            "tmux new-session -A -s ",
            "tmux new-session -s ",
            "tmux attach-session -t ",
        ]
        for prefix in prefixes {
            guard command.hasPrefix(prefix) else { continue }
            let rest = String(command.dropFirst(prefix.count))
            guard rest.count >= 2, rest.first == "'", rest.last == "'" else { return nil }
            var inner = String(rest.dropFirst().dropLast())
            if inner.hasPrefix("=") { inner.removeFirst() }
            guard (try? validateName(inner)) != nil else { return nil }
            return inner
        }
        return nil
    }

    /// Call from a background queue — this blocks on `Process` for up to 8s.
    static func listSessions(
        binary: String? = nil,
        runner: TmuxRunner = .live
    ) throws -> [String] {
        let exe = try resolved(binary)
        let result = runner.run(["list-sessions", "-F", "#{session_name}"], binary: exe, in: "/")
        if result.status != 0 { return [] }
        return parseSessionList(result.stdout)
    }

    /// Call from a background queue — this blocks on `Process` for up to 8s.
    static func listSessionRecords(
        binary: String? = nil,
        runner: TmuxRunner = .live
    ) throws -> [Session] {
        let exe = try resolved(binary)
        let result = runner.run(
            ["list-sessions", "-F", "#{session_name}\t#{session_windows}\t#{session_attached}"],
            binary: exe,
            in: "/"
        )
        if result.status != 0 { return [] }
        return parseSessionRecords(result.stdout)
    }

    static func hasSession(
        name: String,
        binary: String? = nil,
        runner: TmuxRunner = .live
    ) throws -> Bool {
        let name = try canonicalName(name)
        let exe = try resolved(binary)
        let result = runner.run(["has-session", "-t", "=\(name)"], binary: exe, in: "/")
        return result.status == 0
    }

    /// argv-only. Validates the name, then `kill-session -t =<name>`.
    /// Call from a background queue — this blocks on `Process` for up to 8s.
    static func killSession(
        name: String,
        binary: String? = nil,
        runner: TmuxRunner = .live
    ) throws {
        let name = try canonicalName(name)
        let exe = try resolved(binary)
        let result = runner.run(["kill-session", "-t", "=\(name)"], binary: exe, in: "/")
        guard result.status == 0 else {
            throw Error.tmuxFailed("kill-session failed")
        }
    }

    private static func canonicalName(_ name: String) throws -> String {
        try validateName(name)
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolved(_ binary: String?) throws -> String {
        if let binary { return binary }
        guard let found = resolveBinary() else { throw Error.tmuxMissing }
        return found
    }
}

struct TmuxRunner: Sendable {
    private let execute: @Sendable ([String], String, String) -> (status: Int32, stdout: String, stderr: String)

    init(_ execute: @escaping @Sendable ([String], String, String) -> (status: Int32, stdout: String, stderr: String)) {
        self.execute = execute
    }

    func run(_ args: [String], binary: String, in cwd: String) -> (status: Int32, stdout: String, stderr: String) {
        execute(args, binary, cwd)
    }

    static let live = process()

    static func process(timeout: TimeInterval = 8) -> TmuxRunner {
        TmuxRunner { args, binary, cwd in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: cwd, isDirectory: true)
        process.standardInput = FileHandle.nullDevice
        let captureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-tmux-\(UUID().uuidString)", isDirectory: true)
        let stdoutURL = captureRoot.appendingPathComponent("stdout")
        let stderrURL = captureRoot.appendingPathComponent("stderr")
        do {
            try FileManager.default.createDirectory(at: captureRoot, withIntermediateDirectories: true)
            _ = FileManager.default.createFile(
                atPath: stdoutURL.path,
                contents: nil,
                attributes: [.posixPermissions: 0o600]
            )
            _ = FileManager.default.createFile(
                atPath: stderrURL.path,
                contents: nil,
                attributes: [.posixPermissions: 0o600]
            )
            let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            let stderrHandle = try FileHandle(forWritingTo: stderrURL)
            defer {
                try? stdoutHandle.close()
                try? stderrHandle.close()
                try? FileManager.default.removeItem(at: captureRoot)
            }
            process.standardOutput = stdoutHandle
            process.standardError = stderrHandle
            try process.run()
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            let timedOut = process.isRunning
            if timedOut {
                process.terminate()
                Thread.sleep(forTimeInterval: 0.2)
                if process.isRunning {
                    _ = Darwin.kill(process.processIdentifier, SIGKILL)
                }
            }
            process.waitUntilExit()
            func readPrefix(_ url: URL) -> String {
                guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
                defer { try? handle.close() }
                let data = handle.readData(ofLength: 1_048_576)
                return String(decoding: data, as: UTF8.self)
            }
            if timedOut { return (124, readPrefix(stdoutURL), "tmux timed out") }
            return (process.terminationStatus, readPrefix(stdoutURL), readPrefix(stderrURL))
        } catch {
            try? FileManager.default.removeItem(at: captureRoot)
            return (127, "", "tmux could not start")
        }
        }
    }
}
