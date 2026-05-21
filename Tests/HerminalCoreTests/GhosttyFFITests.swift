import Testing
import HerminalCore

/// Smoke test: proves the libghostty C ABI is reachable from Swift through
/// the GhosttyKit binary target. If this fails, the FFI bridge is broken.
@Suite("libghostty FFI bridge")
struct GhosttyFFITests {
    @Test("ghostty_info returns a non-empty semantic version")
    func infoReturnsVersion() {
        let info = Ghostty.info
        #expect(!info.version.isEmpty)
        #expect(info.version != "unknown")
        #expect(info.version.contains("."))
    }

    @Test("ghostty_info reports a known build mode")
    func infoReportsBuildMode() {
        #expect(Ghostty.info.buildMode != .unknown)
    }
}
