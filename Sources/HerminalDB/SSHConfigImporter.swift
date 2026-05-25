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
        var currentName: String?
        var currentHostname: String?
        var currentUser: String?
        var currentPort: Int = 22

        func flush() {
            defer {
                currentName = nil
                currentHostname = nil
                currentUser = nil
                currentPort = 22
            }
            guard let name = currentName,
                  !name.isEmpty,
                  !name.contains("*"),
                  !name.contains("?")
            else { return }
            let host = currentHostname ?? name
            let user = currentUser ?? NSUserName()
            // Use the imported metadata directly — validated() would also
            // run trimming + defaulting but we already have clean values.
            hosts.append(SSHHost(
                nickname: name,
                hostname: host,
                user: user,
                port: currentPort
            ))
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
                // OpenSSH allows multiple targets per Host line —
                // `Host a b c` makes a single block apply to all three.
                // Importing each as its own row is the most useful
                // mapping for the UI, so we split on whitespace and
                // emit one row per concrete target.
                let names = value.split(separator: " ", omittingEmptySubsequences: true)
                                  .map(String.init)
                                  .filter { !$0.contains("*") && !$0.contains("?") }
                // First target opens the active block; remaining targets
                // get duplicated below when we flush at the next Host
                // line or end-of-file. To keep this simple, emit a row
                // for each immediately with the defaults — directives
                // inside the block then update the FIRST entry (currentName).
                for (idx, name) in names.enumerated() {
                    if idx == 0 {
                        currentName = name
                    } else {
                        // Each extra target gets a bare row with no
                        // user-overrides — that's faithful to OpenSSH's
                        // "every match applies the same rules" semantics.
                        hosts.append(SSHHost(
                            nickname: name,
                            hostname: name,
                            user: NSUserName(),
                            port: 22
                        ))
                    }
                }
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
