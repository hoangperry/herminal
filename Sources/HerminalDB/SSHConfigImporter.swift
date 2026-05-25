// SSHConfigImporter — parse ~/.ssh/config into SSHHost rows.
//
// We only handle the subset of OpenSSH's config syntax that maps cleanly
// onto SSHHost (Host / HostName / User / Port). Anything else (IdentityFile,
// ProxyCommand, …) is ignored — the goal isn't to be ssh(1), it's to
// pre-populate the connection manager so the user doesn't retype hosts
// they already configured.
//
// Wildcard Host blocks (`Host *`, `Host *.example.com`) are skipped —
// they're rules, not hosts. Match blocks ditto.

import Foundation

public enum SSHConfigImporter {
    public enum ImportError: Error, Equatable {
        case fileMissing(path: String)
        case readFailed(String)
    }

    /// Reads `path` (defaults to `~/.ssh/config`), parses every concrete
    /// Host block, and returns the corresponding `SSHHost` rows. The
    /// caller decides what to do with conflicts against an existing
    /// store (upsert overwrites by id, so generating new UUIDs per
    /// import yields additive merges).
    public static func parseHosts(
        at path: String = "\(NSHomeDirectory())/.ssh/config"
    ) throws -> [SSHHost] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            throw ImportError.fileMissing(path: path)
        }
        let content: String
        do {
            content = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw ImportError.readFailed("\(error)")
        }
        return parse(content: content)
    }

    /// Pure parser — exposed for tests that don't want to touch disk.
    /// Walks lines, gathers `Host` blocks (skipping wildcards), maps
    /// each one's directives to an `SSHHost`.
    public static func parse(content: String) -> [SSHHost] {
        var hosts: [SSHHost] = []
        // M11-A2 fix (HIGH H-5 from code-reviewer): buffer EVERY name in
        // the current Host block, then emit one row per name when the
        // block closes (next Host, Match, or EOF). The previous version
        // emitted secondary names IMMEDIATELY with defaults — so
        // `Host a b` followed by `HostName real.example.com` produced
        // `b → b` (wrong: should be `b → real.example.com`). OpenSSH
        // applies every directive in the block to every name in the
        // Host line, and this version does too.
        var currentNames: [String] = []
        var currentHostname: String?
        var currentUser: String?
        var currentPort: Int = 22

        func flush() {
            defer {
                currentNames.removeAll()
                currentHostname = nil
                currentUser = nil
                currentPort = 22
            }
            for name in currentNames {
                guard !name.isEmpty,
                      !name.contains("*"),
                      !name.contains("?")
                else { continue }
                let host = currentHostname ?? name
                let user = currentUser ?? NSUserName()
                hosts.append(SSHHost(
                    nickname: name,
                    hostname: host,
                    user: user,
                    port: currentPort
                ))
            }
        }

        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine
                .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespaces) ?? ""
            if line.isEmpty { continue }
            let parts = line.split(separator: " ", maxSplits: 1,
                                   omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).lowercased()
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            switch key {
            case "host":
                flush()
                // Split on whitespace; wildcard / pattern targets are
                // dropped via the filter inside `flush()` (so a `Host * test`
                // line still emits the `test` row).
                currentNames = value
                    .split(separator: " ", omittingEmptySubsequences: true)
                    .map(String.init)
            case "hostname":
                currentHostname = value
            case "user":
                currentUser = value
            case "port":
                currentPort = Int(value) ?? 22
            case "match":
                // Match blocks change scope based on runtime conditions —
                // we can't honour them statically, so we flush and ignore.
                flush()
            default:
                // Unknown directive — skip without flushing so the active
                // Host block keeps accumulating its known keys.
                continue
            }
        }
        flush()
        return hosts
    }
}
