// HerminalCore — libghostty C ABI bindings and Swift wrapper.
// Owns: terminal session lifecycle, PTY plumbing via libghostty, event bridge to AppKit.
// Does NOT own: SwiftUI views, SQLite, agent heuristics.

import Foundation
import GhosttyKit

public enum HerminalCore {
    public static let version = "0.0.1-pre-alpha"
}

/// Bridge that lets `GhosttyApp`'s clipboard callbacks find the live
/// `ghostty_surface_t` for whichever surface libghostty is asking about.
///
/// libghostty hands us back the per-surface userdata pointer we set in
/// `config.userdata` (an opaque view reference). We need the actual C
/// surface handle to call `ghostty_surface_complete_clipboard_request`.
/// The view layer (HerminalApp) conforms its surface NSView to this
/// protocol; `GhosttyApp` only sees the protocol so the module
/// boundary stays clean. Public + AnyObject so we can round-trip
/// through `Unmanaged`.
public protocol ClipboardOwner: AnyObject {
    var surface: ghostty_surface_t? { get }
}

// MARK: - libghostty bridge

/// Thin Swift wrapper over the embedded libghostty C ABI.
public enum Ghostty {
    /// A live surface's grid and cell metrics, in device pixels.
    ///
    /// The pane's pixel size is ours to choose, but the terminal grid is a
    /// whole number of cells. These numbers say how libghostty actually
    /// divided the space, so the layout can tell whether any of it is going
    /// to a partial row — see issue #32.
    public struct SurfaceMetrics: Sendable, Equatable {
        public let columns: Int
        public let rows: Int
        public let widthPx: Int
        public let heightPx: Int
        public let cellWidthPx: Int
        public let cellHeightPx: Int

        /// Pixels left over after the whole rows: `heightPx - rows * cellHeightPx`.
        /// Zero means the surface divides evenly.
        public var verticalSlackPx: Int { heightPx - rows * cellHeightPx }
        /// Same, across: `widthPx - columns * cellWidthPx`.
        public var horizontalSlackPx: Int { widthPx - columns * cellWidthPx }
    }

    /// Reads a surface's current grid + cell metrics.
    public static func metrics(of surface: ghostty_surface_t) -> SurfaceMetrics {
        let size = ghostty_surface_size(surface)
        return SurfaceMetrics(
            columns: Int(size.columns),
            rows: Int(size.rows),
            widthPx: Int(size.width_px),
            heightPx: Int(size.height_px),
            cellWidthPx: Int(size.cell_width_px),
            cellHeightPx: Int(size.cell_height_px)
        )
    }

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
