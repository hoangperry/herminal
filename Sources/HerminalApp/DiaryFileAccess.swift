import Darwin
import Foundation

/// Descriptor-anchored file operations for the local crash diary.
enum DiaryFileAccess {
    static let maximumFileBytes = 1_048_576

    static func preparePrivateDirectory(in parentURL: URL, name: String) -> URL? {
        guard isValidComponent(name) else { return nil }
        let parentDescriptor = Darwin.open(
            parentURL.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard parentDescriptor >= 0 else { return nil }
        defer { Darwin.close(parentDescriptor) }

        guard mkdirat(parentDescriptor, name, 0o700) == 0 || errno == EEXIST else {
            return nil
        }
        let directoryDescriptor = openat(
            parentDescriptor,
            name,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard directoryDescriptor >= 0 else { return nil }
        defer { Darwin.close(directoryDescriptor) }

        var directoryInfo = stat()
        guard fstat(directoryDescriptor, &directoryInfo) == 0,
              directoryInfo.st_mode & S_IFMT == S_IFDIR,
              directoryInfo.st_uid == geteuid(),
              fchmod(directoryDescriptor, 0o700) == 0,
              fstat(directoryDescriptor, &directoryInfo) == 0,
              directoryInfo.st_mode & 0o777 == 0o700
        else { return nil }
        return parentURL.appendingPathComponent(name, isDirectory: true)
    }

    static func openFile(at url: URL) -> FileHandle? {
        let fileName = url.lastPathComponent
        guard isValidComponent(fileName) else { return nil }
        let directoryDescriptor = Darwin.open(
            url.deletingLastPathComponent().path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard directoryDescriptor >= 0 else { return nil }
        defer { Darwin.close(directoryDescriptor) }

        var directoryInfo = stat()
        guard fstat(directoryDescriptor, &directoryInfo) == 0,
              directoryInfo.st_mode & S_IFMT == S_IFDIR,
              directoryInfo.st_uid == geteuid(),
              directoryInfo.st_mode & 0o077 == 0
        else { return nil }

        let descriptor = openat(
            directoryDescriptor,
            fileName,
            O_RDWR | O_APPEND | O_CREAT | O_CLOEXEC | O_NOFOLLOW,
            0o600
        )
        guard descriptor >= 0 else { return nil }
        var fileInfo = stat()
        guard fstat(descriptor, &fileInfo) == 0,
              fileInfo.st_mode & S_IFMT == S_IFREG,
              fileInfo.st_uid == geteuid(),
              fileInfo.st_nlink == 1,
              fchmod(descriptor, 0o600) == 0
        else {
            Darwin.close(descriptor)
            return nil
        }

        let activeDescriptor = compactedDescriptor(
            descriptor,
            fileInfo: fileInfo,
            directoryDescriptor: directoryDescriptor,
            fileName: fileName
        )
        if activeDescriptor != descriptor { Darwin.close(descriptor) }
        return FileHandle(fileDescriptor: activeDescriptor, closeOnDealloc: true)
    }

    static func persistedData(from fileHandle: FileHandle?) -> Data? {
        guard let descriptor = fileHandle?.fileDescriptor else { return nil }
        var fileInfo = stat()
        guard fstat(descriptor, &fileInfo) == 0, fileInfo.st_size > 0 else { return nil }
        let byteCount = min(Int(fileInfo.st_size), maximumFileBytes)
        let offset = fileInfo.st_size - off_t(byteCount)
        return readExactly(from: descriptor, byteCount: byteCount, offset: offset)
    }

    /// Compacts through a same-directory temporary file and atomic rename.
    /// Failures before rename leave the original inode untouched. Herminal's
    /// normal LaunchServices lifecycle is single-instance; independently
    /// forced concurrent instances do not coordinate startup compaction.
    private static func compactedDescriptor(
        _ descriptor: Int32,
        fileInfo: stat,
        directoryDescriptor: Int32,
        fileName: String
    ) -> Int32 {
        guard fileInfo.st_size > off_t(maximumFileBytes) else { return descriptor }
        let tailOffset = fileInfo.st_size - off_t(maximumFileBytes)
        guard let tail = readExactly(
            from: descriptor,
            byteCount: maximumFileBytes,
            offset: tailOffset
        ) else { return descriptor }

        let temporaryName = ".\(fileName).\(UUID().uuidString).tmp"
        let replacement = openat(
            directoryDescriptor,
            temporaryName,
            O_RDWR | O_APPEND | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            0o600
        )
        guard replacement >= 0 else { return descriptor }
        var didInstallReplacement = false
        defer {
            if !didInstallReplacement {
                Darwin.close(replacement)
                _ = unlinkat(directoryDescriptor, temporaryName, 0)
            }
        }

        guard writeExactly(tail, to: replacement), fsync(replacement) == 0,
              renameat(
                  directoryDescriptor,
                  temporaryName,
                  directoryDescriptor,
                  fileName
              ) == 0
        else { return descriptor }
        // The file data is durable before rename. Directory fsync is best
        // effort because the rename cannot be safely rolled back afterward.
        _ = fsync(directoryDescriptor)
        didInstallReplacement = true
        return replacement
    }

    private static func isValidComponent(_ component: String) -> Bool {
        !component.isEmpty && component != "." && component != ".."
            && !component.contains("/") && !component.contains("\0")
    }

    private static func readExactly(
        from descriptor: Int32,
        byteCount: Int,
        offset: off_t
    ) -> Data? {
        var data = Data(count: byteCount)
        let didReadAll = data.withUnsafeMutableBytes { bytes -> Bool in
            guard let baseAddress = bytes.baseAddress else { return byteCount == 0 }
            var totalRead = 0
            while totalRead < byteCount {
                let result = pread(
                    descriptor,
                    baseAddress.advanced(by: totalRead),
                    byteCount - totalRead,
                    offset + off_t(totalRead)
                )
                if result > 0 {
                    totalRead += result
                } else if result < 0, errno == EINTR {
                    continue
                } else {
                    return false
                }
            }
            return true
        }
        return didReadAll ? data : nil
    }

    private static func writeExactly(_ data: Data, to descriptor: Int32) -> Bool {
        data.withUnsafeBytes { bytes -> Bool in
            guard let baseAddress = bytes.baseAddress else { return data.isEmpty }
            var totalWritten = 0
            while totalWritten < data.count {
                let result = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: totalWritten),
                    data.count - totalWritten
                )
                if result > 0 {
                    totalWritten += result
                } else if result < 0, errno == EINTR {
                    continue
                } else {
                    return false
                }
            }
            return true
        }
    }
}
