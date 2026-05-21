// HerminalCore — libghostty C ABI bindings and Swift wrapper.
// Owns: terminal session lifecycle, PTY plumbing via libghostty, event bridge to AppKit.
// Does NOT own: SwiftUI views, SQLite, agent heuristics.

import Foundation
import GhosttyKit

public enum HerminalCore {
    public static let version = "0.0.1-pre-alpha"
}

// MARK: - libghostty bridge

/// Thin Swift wrapper over the embedded libghostty C ABI.
public enum Ghostty {
    /// Build information reported by the embedded libghostty.
    public struct Info: Sendable, Equatable {
        public enum BuildMode: String, Sendable {
            case debug
            case releaseSafe
            case releaseFast
            case releaseSmall
            case unknown
        }

        public let buildMode: BuildMode
        public let version: String
    }

    /// Build info from the embedded libghostty.
    /// Safe to call without `ghostty_init` — this is the FFI smoke test entry point.
    public static var info: Info {
        let raw = ghostty_info()

        let version: String
        if let ptr = raw.version, raw.version_len > 0 {
            version = String(
                decoding: UnsafeRawBufferPointer(start: ptr, count: Int(raw.version_len)),
                as: UTF8.self
            )
        } else {
            version = "unknown"
        }

        let mode: Info.BuildMode = switch raw.build_mode {
        case GHOSTTY_BUILD_MODE_DEBUG: .debug
        case GHOSTTY_BUILD_MODE_RELEASE_SAFE: .releaseSafe
        case GHOSTTY_BUILD_MODE_RELEASE_FAST: .releaseFast
        case GHOSTTY_BUILD_MODE_RELEASE_SMALL: .releaseSmall
        default: .unknown
        }

        return Info(buildMode: mode, version: version)
    }
}
