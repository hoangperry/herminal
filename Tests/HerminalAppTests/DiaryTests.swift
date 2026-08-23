import Foundation
import Darwin
import Testing
@testable import HerminalApp

@Suite("Diary")
struct DiaryTests {
    /// The diary is a singleton because the crash-signal handler can only
    /// hold one open file descriptor — so these tests share the live
    /// instance rather than mock it. We only assert behaviours that don't
    /// race with the periodic flush timer.
    private var diary: Diary { Diary.shared }

    @Test("log appends to the in-memory ring buffer")
    func logAppends() async throws {
        let marker = "diary-test-\(UUID().uuidString)"
        diary.log(marker, category: "test")
        // log() dispatches onto a serial queue — give it a beat so the
        // ring write definitely lands before we read it back.
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(diary.recentEntries().contains(where: { $0.contains(marker) }))
    }

    @Test("log entries carry the supplied category")
    func categoryAppearsInEntry() async throws {
        let marker = "cat-test-\(UUID().uuidString)"
        diary.log(marker, category: "ssh")
        try await Task.sleep(nanoseconds: 100_000_000)
        let hit = diary.recentEntries().first { $0.contains(marker) }
        let entry = try #require(hit)
        #expect(entry.contains("[ssh]"))
    }

    @Test("log entries start with an ISO 8601 timestamp")
    func entryHasTimestamp() async throws {
        let marker = "stamp-test-\(UUID().uuidString)"
        diary.log(marker, category: "test")
        try await Task.sleep(nanoseconds: 100_000_000)
        let hit = diary.recentEntries().first { $0.contains(marker) }
        let entry = try #require(hit)
        // ISO 8601 with fractional seconds always begins with a 4-digit
        // year + a `-`. Cheap shape check that survives time-zone drift.
        let year = entry.prefix(4)
        #expect(year.allSatisfy { $0.isNumber })
        #expect(entry[entry.index(entry.startIndex, offsetBy: 4)] == "-")
    }

    @Test("flush completes without blocking forever")
    func flushReturns() async throws {
        diary.log("pre-flush", category: "test")
        // If the queue were to deadlock the test would hang here. We let
        // Swift Testing's default timeout (60s) catch that case.
        diary.flush()
    }

    @Test("Diary file open refuses symlinks without touching their target")
    func openFileRejectsSymlinks() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-symlink-\(UUID().uuidString)")
        let targetURL = directory.appendingPathComponent("target.log")
        let symlinkURL = directory.appendingPathComponent("diary.log")
        let sentinel = "must remain unchanged"
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #expect(chmod(directory.path, 0o700) == 0)
        defer { try? FileManager.default.removeItem(at: directory) }
        try sentinel.write(to: targetURL, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: symlinkURL,
            withDestinationURL: targetURL
        )

        let handle = Diary.openFile(at: symlinkURL)
        try handle?.close()

        #expect(handle == nil)
        #expect(try String(contentsOf: targetURL, encoding: .utf8) == sentinel)
    }

    @Test("Diary file open retains only the capped tail")
    func openFileRetainsCappedTail() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-tail-\(UUID().uuidString).log")
        let maximumFileBytes = 1_048_576
        let expectedTail = Data(repeating: 0x42, count: maximumFileBytes)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        var oversized = Data(repeating: 0x41, count: 32)
        oversized.append(expectedTail)
        try oversized.write(to: fileURL)

        let handle = try #require(Diary.openFile(at: fileURL))
        try handle.close()

        #expect(try Data(contentsOf: fileURL) == expectedTail)
    }

    @Test("Diary file open enforces owner-only permissions")
    func openFileEnforcesOwnerOnlyPermissions() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-mode-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let handle = try #require(Diary.openFile(at: fileURL))
        try handle.close()
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)

        #expect(permissions.intValue & 0o777 == 0o600)
    }

    @Test("Diary file open rejects hard links")
    func openFileRejectsHardLinks() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-hardlink-\(UUID().uuidString)")
        let targetURL = directory.appendingPathComponent("target.log")
        let hardLinkURL = directory.appendingPathComponent("diary.log")
        let sentinel = "hard-link target"
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #expect(chmod(directory.path, 0o700) == 0)
        defer { try? FileManager.default.removeItem(at: directory) }
        try sentinel.write(to: targetURL, atomically: true, encoding: .utf8)
        try FileManager.default.linkItem(at: targetURL, to: hardLinkURL)

        let handle = Diary.openFile(at: hardLinkURL)
        try handle?.close()

        #expect(handle == nil)
        #expect(try String(contentsOf: targetURL, encoding: .utf8) == sentinel)
    }

    @Test("Diary file open rejects a symlinked parent directory")
    func openFileRejectsSymlinkedParent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-parent-\(UUID().uuidString)")
        let realDirectory = root.appendingPathComponent("real", isDirectory: true)
        let symlinkDirectory = root.appendingPathComponent("redirect", isDirectory: true)
        let fileURL = symlinkDirectory.appendingPathComponent("diary.log")
        try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(
            at: symlinkDirectory,
            withDestinationURL: realDirectory
        )

        let handle = Diary.openFile(at: fileURL)
        try handle?.close()

        #expect(handle == nil)
        #expect(!FileManager.default.fileExists(
            atPath: realDirectory.appendingPathComponent("diary.log").path
        ))
    }

    @Test("Diary directory preparation never chmods a symlink target")
    func prepareLogDirectoryRejectsSymlinkWithoutMutation() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-dir-symlink-\(UUID().uuidString)")
        let target = parent.appendingPathComponent("target", isDirectory: true)
        let symlink = parent.appendingPathComponent("herminal", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        #expect(chmod(target.path, 0o755) == 0)
        defer { try? FileManager.default.removeItem(at: parent) }
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: target)

        let prepared = Diary.prepareLogDirectory(in: parent, name: "herminal")
        let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)

        #expect(prepared == nil)
        #expect(permissions.intValue & 0o777 == 0o755)
    }

    @Test("Diary directory preparation enforces owner-only permissions")
    func prepareLogDirectoryEnforcesOwnerOnlyPermissions() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-dir-mode-\(UUID().uuidString)")
        let directory = parent.appendingPathComponent("herminal", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #expect(chmod(directory.path, 0o777) == 0)
        defer { try? FileManager.default.removeItem(at: parent) }

        let prepared = try #require(Diary.prepareLogDirectory(in: parent, name: "herminal"))
        let attributes = try FileManager.default.attributesOfItem(atPath: prepared.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)

        #expect(prepared == directory)
        #expect(permissions.intValue & 0o777 == 0o700)
    }

    @Test("Diary file open rejects a group or world accessible parent")
    func openFileRejectsInsecureParentPermissions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-insecure-dir-\(UUID().uuidString)")
        let fileURL = directory.appendingPathComponent("diary.log")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #expect(chmod(directory.path, 0o777) == 0)
        defer { try? FileManager.default.removeItem(at: directory) }

        let handle = Diary.openFile(at: fileURL)
        try handle?.close()

        #expect(handle == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("Diary file open rejects non-regular files")
    func openFileRejectsFIFO() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-fifo-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        #expect(mkfifo(fileURL.path, 0o600) == 0)

        let handle = Diary.openFile(at: fileURL)
        try handle?.close()

        #expect(handle == nil)
    }

    @Test("failed atomic compaction preserves the oversized diary")
    func failedCompactionPreservesOriginal() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-compact-failure-\(UUID().uuidString)")
        let fileURL = directory.appendingPathComponent("diary.log")
        let oversized = Data(repeating: 0x41, count: 1_048_577)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try oversized.write(to: fileURL)
        #expect(chmod(directory.path, 0o500) == 0)
        defer {
            _ = chmod(directory.path, 0o700)
            try? FileManager.default.removeItem(at: directory)
        }

        let handle = try #require(Diary.openFile(at: fileURL))
        try handle.close()

        #expect(try Data(contentsOf: fileURL) == oversized)
    }

    @Test("crash descriptor duplication is atomic CLOEXEC and preserves the inode")
    func crashDescriptorDuplicationPreservesFlagsAndInode() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-crash-fd-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let handle = try #require(Diary.openFile(at: fileURL))
        defer { try? handle.close() }

        let duplicate = Diary.duplicateCrashDescriptor(from: handle.fileDescriptor)
        defer { if duplicate >= 0 { Darwin.close(duplicate) } }
        var originalInfo = stat()
        var duplicateInfo = stat()

        #expect(duplicate >= 0)
        #expect(fcntl(duplicate, F_GETFD) & FD_CLOEXEC != 0)
        #expect(fcntl(duplicate, F_GETFL) & O_APPEND != 0)
        #expect(fstat(handle.fileDescriptor, &originalInfo) == 0)
        #expect(fstat(duplicate, &duplicateInfo) == 0)
        #expect(originalInfo.st_dev == duplicateInfo.st_dev)
        #expect(originalInfo.st_ino == duplicateInfo.st_ino)
    }

    @Test("crash messages are precomputed without changing their format", arguments: [
        (SIGSEGV, "\n=== CRASHED signal=11 ===\n"),
        (SIGBUS, "\n=== CRASHED signal=10 ===\n"),
        (SIGABRT, "\n=== CRASHED signal=6 ===\n"),
        (SIGILL, "\n=== CRASHED signal=4 ===\n"),
        (SIGFPE, "\n=== CRASHED signal=8 ===\n"),
    ])
    func crashMessagesArePrecomputed(signal: Int32, expected: String) {
        #expect(Diary.preparedCrashMessage(for: signal) == expected)
    }

    @Test("unregistered signals have no crash message")
    func unregisteredCrashSignalsHaveNoMessage() {
        #expect(Diary.preparedCrashMessage(for: SIGTERM) == nil)
    }

    // MARK: - M9/F redaction

    @Test("redact rewrites the current user's home prefix")
    func redactRewritesOwnHome() {
        let home = NSHomeDirectory()
        let input = "saved note at \(home)/Library/Application Support/herminal/notes.db"
        let out = Diary.redact(input)
        #expect(!out.contains(home))
        #expect(out.contains("/Users/<redacted>"))
    }

    @Test("redact catches other /Users/* paths too")
    func redactCatchesOtherUsers() {
        let input = "diff between /Users/alice/x and /Users/bob/y"
        let out = Diary.redact(input)
        #expect(!out.contains("/Users/alice"))
        #expect(!out.contains("/Users/bob"))
        // Replaced count == 2.
        let count = out.components(separatedBy: "/Users/<redacted>").count - 1
        #expect(count == 2)
    }

    @Test("redact anonymises libghostty surface addresses")
    func redactSurfaceAddresses() {
        let input = "[bell] surface=0x7f9c8e003a40 rang"
        let out = Diary.redact(input)
        #expect(out.contains("0x<addr>"))
        #expect(!out.contains("0x7f9c8e003a40"))
    }

    @Test("redact preserves PIDs — they're useful and not PII")
    func redactKeepsPIDs() {
        let input = "[lifecycle] === herminal launched pid=12345 ==="
        let out = Diary.redact(input)
        #expect(out.contains("pid=12345"))
    }

    @Test("exportRedacted returns recent entries with all rules applied")
    func exportRedactedRunsRules() async throws {
        // Seed a small, deterministic shape — diary singleton shares
        // state across cases so we tolerate older entries by suffix.
        let home = NSHomeDirectory()
        diary.log("note at \(home)/file", category: "test")
        diary.log("[bell] surface=0xfeedbeef rang", category: "test")
        try await Task.sleep(nanoseconds: 100_000_000)
        let out = diary.exportRedacted(maxLines: 200)
        #expect(!out.contains(home))
        #expect(!out.contains("0xfeedbeef"))
        #expect(out.contains("/Users/<redacted>"))
        #expect(out.contains("0x<addr>"))
    }

    @Test("redacted export reads the persisted tail from before relaunch")
    func exportRedactedReadsPersistedTail() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-export-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try """
            [workspace] /Users/alice/project
            [crash] CRASHED signal=11
            [lifecycle] herminal relaunched
            """.write(to: fileURL, atomically: true, encoding: .utf8)

        let handle = try #require(Diary.openFile(at: fileURL))
        defer { try? handle.close() }
        let output = Diary.exportRedacted(
            from: handle,
            fallbackEntries: ["fallback must not win"],
            maxLines: 2
        )

        #expect(output.contains("CRASHED signal=11"))
        #expect(output.contains("herminal relaunched"))
        #expect(!output.contains("fallback must not win"))
        #expect(!output.contains("/Users/alice"))
    }

    @Test("redacted export remains bound to the verified file after a path swap")
    func exportRedactedIgnoresPostOpenSymlinkSwap() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-diary-export-swap-\(UUID().uuidString)")
        let fileURL = directory.appendingPathComponent("diary.log")
        let secretURL = directory.appendingPathComponent("secret.txt")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #expect(chmod(directory.path, 0o700) == 0)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "verified diary entry".write(to: fileURL, atomically: true, encoding: .utf8)
        try "must never be exported".write(to: secretURL, atomically: true, encoding: .utf8)
        let handle = try #require(Diary.openFile(at: fileURL))
        defer { try? handle.close() }
        try FileManager.default.removeItem(at: fileURL)
        try FileManager.default.createSymbolicLink(at: fileURL, withDestinationURL: secretURL)

        let output = Diary.exportRedacted(
            from: handle,
            fallbackEntries: ["fallback"],
            maxLines: 10
        )

        #expect(output.contains("verified diary entry"))
        #expect(!output.contains("must never be exported"))
        #expect(!output.contains("fallback"))
    }
}
