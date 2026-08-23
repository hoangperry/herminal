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

import CryptoKit
import Foundation

public enum SSHConfigImporter {
    private static let importIDNamespace = "herminal:ssh-config"

    private struct ImportedHostValues {
        let nickname: String
        var hostname: String?
        var user: String?
        var port: Int?
    }

    public enum ImportError: Error, Equatable {
        case fileMissing(path: String)
        case fileTooLarge(path: String, bytes: Int)
        case readFailed(String)
    }

    /// Importing SSH metadata should never require reading an unbounded file.
    /// A normal OpenSSH config is measured in KB; 1 MiB leaves ample room for
    /// generated configs while preventing accidental memory/CPU abuse.
    public static let maxConfigBytes = 1_048_576

    /// Reads `path` (defaults to `~/.ssh/config`), parses every concrete
    /// Host block, and returns the corresponding `SSHHost` rows. Imported
    /// aliases receive stable IDs, so a later import refreshes the matching
    /// saved row instead of appending a duplicate.
    public static func parseHosts(
        at path: String = "\(NSHomeDirectory())/.ssh/config"
    ) throws -> [SSHHost] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            throw ImportError.fileMissing(path: path)
        }
        let data: Data
        do {
            let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
            defer { try? handle.close() }
            data = try handle.read(upToCount: maxConfigBytes + 1) ?? Data()
        } catch {
            throw ImportError.readFailed("\(error)")
        }
        guard data.count <= maxConfigBytes else {
            throw ImportError.fileTooLarge(path: path, bytes: data.count)
        }
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.readFailed("SSH config is not valid UTF-8")
        }
        return parse(content: content)
    }

    /// Pure parser — exposed for tests that don't want to touch disk.
    /// Walks lines, gathers `Host` blocks (skipping wildcards), maps
    /// each one's directives to an `SSHHost`, and merges repeated aliases
    /// using OpenSSH's first-obtained-value precedence.
    public static func parse(content: String) -> [SSHHost] {
        var aliasOrder: [String] = []
        var valuesByAlias: [String: ImportedHostValues] = [:]
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
        var currentPort: Int?

        func flush() {
            defer {
                currentNames.removeAll()
                currentHostname = nil
                currentUser = nil
                currentPort = nil
            }
            for name in currentNames {
                guard isConcreteHostAlias(name) else { continue }
                let key = normalizedAlias(name)
                var values = valuesByAlias[key] ?? ImportedHostValues(
                    nickname: name,
                    hostname: nil,
                    user: nil,
                    port: nil
                )
                if valuesByAlias[key] == nil {
                    aliasOrder.append(key)
                }
                if values.hostname == nil {
                    values.hostname = currentHostname
                }
                if values.user == nil {
                    values.user = currentUser
                }
                if values.port == nil {
                    values.port = currentPort
                }
                valuesByAlias[key] = values
            }
        }

        for rawLine in content.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ) {
            guard let tokens = directiveTokens(in: rawLine),
                  let rawKey = tokens.first,
                  tokens.count > 1
            else { continue }
            let key = rawKey.lowercased()
            let arguments = Array(tokens.dropFirst())
            let value = arguments.joined(separator: " ")
            switch key {
            case "host":
                flush()
                // Wildcard / negated pattern targets are dropped via the
                // filter inside `flush()` (so a `Host * test` or
                // `Host !prod test` line still emits the concrete `test`
                // row). Quoted targets remain one alias.
                currentNames = arguments
            case "hostname":
                currentHostname = value
            case "user":
                currentUser = value
            case "port":
                currentPort = Int(value)
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
        return aliasOrder.compactMap { key in
            guard let values = valuesByAlias[key] else { return nil }
            return SSHHost(
                id: stableImportedID(for: values.nickname),
                nickname: values.nickname,
                hostname: values.hostname ?? values.nickname,
                user: values.user ?? NSUserName(),
                port: values.port ?? 22
            )
        }
    }

    /// Tokenizes the small OpenSSH grammar surface this importer supports.
    /// The first separator may be whitespace or one `=` with optional
    /// surrounding whitespace. Later `=` characters belong to the argument.
    /// Double quotes group whitespace and protect `#` from starting a comment.
    private static func directiveTokens(in line: Substring) -> [String]? {
        var tokens: [String] = []
        var current = ""
        var tokenStarted = false
        var isQuoted = false
        var consumedEqualsSeparator = false

        func finishToken() {
            guard tokenStarted else { return }
            tokens.append(current)
            current = ""
            tokenStarted = false
        }

        for character in line {
            if character == "\"" {
                isQuoted.toggle()
                tokenStarted = true
                continue
            }
            if character == "#", !isQuoted {
                break
            }
            if character.isWhitespace, !isQuoted {
                finishToken()
                continue
            }
            if character == "=", !isQuoted,
               !consumedEqualsSeparator,
               tokens.isEmpty || (tokens.count == 1 && !tokenStarted) {
                finishToken()
                guard tokens.count == 1 else { return nil }
                consumedEqualsSeparator = true
                continue
            }
            current.append(character)
            tokenStarted = true
        }

        guard !isQuoted else { return nil }
        finishToken()
        return tokens.isEmpty ? nil : tokens
    }

    /// Retry/import-again must refresh the same saved rows rather than append
    /// duplicates, so concrete aliases from `~/.ssh/config` get deterministic
    /// IDs derived from the alias itself.
    private static func stableImportedID(for nickname: String) -> UUID {
        let digest = SHA256.hash(
            data: Data("\(importIDNamespace):\(normalizedAlias(nickname))".utf8)
        )
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid = uuid_t(
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }

    private static func normalizedAlias(_ nickname: String) -> String {
        nickname
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func isConcreteHostAlias(_ candidate: String) -> Bool {
        let alias = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !alias.isEmpty,
              alias.first != "!",
              !alias.contains("*"),
              !alias.contains("?")
        else { return false }
        return true
    }
}
