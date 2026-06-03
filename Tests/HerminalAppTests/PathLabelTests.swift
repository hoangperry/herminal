import Foundation
import Testing
@testable import HerminalApp

// PathLabel turns an absolute cwd into the status-bar (~-abbreviated) and
// tab (basename) labels. Pure + home-injectable, so these never depend on
// the test machine's real HOME.
@Suite("PathLabel")
struct PathLabelTests {
    private let home = "/Users/meow"

    @Test("abbreviateHome replaces the home prefix with ~")
    func abbreviatesHomePrefix() {
        #expect(PathLabel.abbreviateHome("/Users/meow/pet/herminal", home: home) == "~/pet/herminal")
    }

    @Test("abbreviateHome maps the home directory itself to ~")
    func abbreviatesHomeItself() {
        #expect(PathLabel.abbreviateHome("/Users/meow", home: home) == "~")
    }

    @Test("abbreviateHome leaves non-home paths untouched")
    func leavesNonHomeAlone() {
        #expect(PathLabel.abbreviateHome("/etc/hosts", home: home) == "/etc/hosts")
        // A path that merely shares a prefix string but isn't under home.
        #expect(PathLabel.abbreviateHome("/Users/meowmeow/x", home: home) == "/Users/meowmeow/x")
    }

    @Test("tabLabel is the last path component")
    func tabLabelBasename() {
        #expect(PathLabel.tabLabel(for: "/Users/meow/pet/herminal", home: home) == "herminal")
    }

    @Test("tabLabel maps the home directory to ~")
    func tabLabelHome() {
        #expect(PathLabel.tabLabel(for: "/Users/meow", home: home) == "~")
    }

    @Test("tabLabel handles root and trailing slashes")
    func tabLabelEdges() {
        #expect(PathLabel.tabLabel(for: "/", home: home) == "/")
        #expect(PathLabel.tabLabel(for: "/Users/meow/pet/api/", home: home) == "api")
    }
}
