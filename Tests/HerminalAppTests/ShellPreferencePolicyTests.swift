import Testing

@testable import HerminalApp

@Suite("Shell preference truthfulness")
struct ShellPreferencePolicyTests {
    @Test("empty shell path presents the active login-shell behavior")
    func emptyPathUsesLoginShell() {
        let presentation = Preferences.shellOverridePresentation(
            for: "   ",
            isExecutable: { _ in false }
        )

        #expect(presentation.kind == .inherited)
        #expect(presentation.message == "Using your macOS login shell for new plain-shell tabs and splits.")
        #expect(
            presentation.fieldAccessibilityHint
                == "Set an absolute executable path, such as /opt/homebrew/bin/fish. New plain-shell tabs and splits start your macOS login shell, then request a handoff to this path."
        )
        #expect(presentation.statusAccessibilityLabel == "Shell override status. \(presentation.message)")
        #expect(presentation.canResetToLoginShell == false)
    }

    @Test("valid executable path is reported as active for new plain shells")
    func validPathIsActiveForNewPlainShells() {
        let presentation = Preferences.shellOverridePresentation(
            for: "/opt/homebrew/bin/fish",
            isExecutable: { _ in true }
        )

        #expect(presentation.kind == .active)
        #expect(
            presentation.message
                == "New plain-shell tabs and splits start your macOS login shell, then request a handoff to /opt/homebrew/bin/fish. Login-shell startup files run first; existing panes are unchanged."
        )
        #expect(
            presentation.fieldAccessibilityHint
                == "Set an absolute executable path, such as /opt/homebrew/bin/fish. New plain-shell tabs and splits start your macOS login shell, then request a handoff to this path."
        )
        #expect(presentation.statusAccessibilityLabel == "Shell override status. \(presentation.message)")
        #expect(presentation.canResetToLoginShell)
    }

    @Test("validated shell override path trims executable absolute paths")
    func validatedShellOverridePathAcceptsExecutableAbsolutePaths() {
        #expect(
            Preferences.validatedShellOverridePath(
                for: " /opt/homebrew/bin/fish ",
                isExecutable: { path in
                    path == "/opt/homebrew/bin/fish"
                },
                resolvePath: { $0 }
            ) == "/opt/homebrew/bin/fish"
        )
    }

    @Test("validated shell override path uses the resolved launch path")
    func validatedShellOverridePathUsesResolvedLaunchPath() {
        #expect(
            Preferences.validatedShellOverridePath(
                for: "/usr/local/bin/fish-link",
                isExecutable: { path in
                    path == "/opt/homebrew/bin/fish"
                },
                resolvePath: { _ in "/opt/homebrew/bin/fish" }
            ) == "/opt/homebrew/bin/fish"
        )
    }

    @Test("relative shell path explains that an absolute path is required")
    func relativePathIsInvalid() {
        let presentation = Preferences.shellOverridePresentation(
            for: "bin/fish",
            isExecutable: { _ in true }
        )

        #expect(presentation.kind == .invalid)
        #expect(presentation.message == "Invalid shell path: enter an absolute path, such as /opt/homebrew/bin/fish. This value is ignored.")
        #expect(presentation.canResetToLoginShell)
    }

    @Test("temporary-directory shell paths are rejected before executable lookup")
    func temporaryPathIsInvalid() {
        var executableLookupCount = 0

        for path in ["/tmp/fish", "/private/tmp/fish"] {
            let presentation = Preferences.shellOverridePresentation(
                for: path,
                isExecutable: { _ in
                    executableLookupCount += 1
                    return true
                }
            )

            #expect(presentation.kind == .invalid)
            #expect(presentation.message == "Invalid shell path: executables under /tmp aren't allowed. This value is ignored.")
            #expect(presentation.canResetToLoginShell)
        }
        #expect(executableLookupCount == 0)
    }

    @Test("paths that resolve through a symlink into /tmp are rejected before executable lookup")
    func symlinkResolvedTemporaryPathIsInvalid() {
        var executableLookupCount = 0
        let presentation = Preferences.shellOverridePresentation(
            for: "/usr/local/bin/fish-link",
            isExecutable: { _ in
                executableLookupCount += 1
                return true
            },
            resolvePath: { _ in "/private/tmp/fish" }
        )

        #expect(presentation.kind == .invalid)
        #expect(presentation.message == "Invalid shell path: executables under /tmp aren't allowed. This value is ignored.")
        #expect(executableLookupCount == 0)
    }

    @Test("control characters are rejected before executable lookup")
    func controlCharactersAreInvalid() {
        let rawPaths = [
            "/opt/homebrew/bin/fish\n",
            "/opt/homebrew/bin/fi\tsh",
            "/opt/homebrew/bin/fish\0backup",
        ]
        var executableLookupCount = 0

        for rawPath in rawPaths {
            let presentation = Preferences.shellOverridePresentation(
                for: rawPath,
                isExecutable: { _ in
                    executableLookupCount += 1
                    return true
                }
            )

            #expect(presentation.kind == .invalid)
            #expect(
                presentation.message
                    == "Invalid shell path: control characters aren't allowed. This value is ignored."
            )
            #expect(
                Preferences.validatedShellOverridePath(
                    for: rawPath,
                    isExecutable: { _ in
                        executableLookupCount += 1
                        return true
                    },
                    resolvePath: { $0 }
                ) == nil
            )
        }

        #expect(executableLookupCount == 0)
    }

    @Test("non-executable absolute shell path explains why it is ignored")
    func nonExecutablePathIsInvalid() {
        let presentation = Preferences.shellOverridePresentation(
            for: "/usr/local/bin/missing-shell",
            isExecutable: { _ in false }
        )

        #expect(presentation.kind == .invalid)
        #expect(presentation.message == "Invalid shell path: no executable file exists at /usr/local/bin/missing-shell. This value is ignored.")
        #expect(presentation.canResetToLoginShell)
    }

    @Test("an executable directory is not accepted as a shell file")
    func executableDirectoryIsInvalid() {
        #expect(
            Preferences.validatedShellOverridePath(
                for: "/",
                resolvePath: { $0 }
            ) == nil
        )
    }

    @Test("clearing a rejected override returns to the login-shell state")
    func clearingOverrideRestoresInheritedState() {
        let invalid = Preferences.shellOverridePresentation(
            for: "fish",
            isExecutable: { _ in false }
        )
        let cleared = Preferences.shellOverridePresentation(
            for: "",
            isExecutable: { _ in false }
        )

        #expect(invalid.kind == .invalid)
        #expect(cleared.kind == .inherited)
        #expect(cleared.message == "Using your macOS login shell for new plain-shell tabs and splits.")
    }

    @Test("shell status announcements fire only when validity state changes")
    func shellStatusAnnouncementPolicy() {
        let inherited = Preferences.shellOverridePresentation(
            for: "",
            isExecutable: { _ in false }
        )
        let invalid = Preferences.shellOverridePresentation(
            for: "fish",
            isExecutable: { _ in false }
        )
        let anotherInvalid = Preferences.shellOverridePresentation(
            for: "bin/fish",
            isExecutable: { _ in false }
        )
        let temporary = Preferences.shellOverridePresentation(
            for: "/tmp/fish",
            isExecutable: { _ in true }
        )
        let missingA = Preferences.shellOverridePresentation(
            for: "/opt/missing-a",
            isExecutable: { _ in false }
        )
        let missingB = Preferences.shellOverridePresentation(
            for: "/opt/missing-b",
            isExecutable: { _ in false }
        )
        let active = Preferences.shellOverridePresentation(
            for: "/opt/homebrew/bin/fish",
            isExecutable: { _ in true }
        )
        let anotherActive = Preferences.shellOverridePresentation(
            for: "/bin/zsh",
            isExecutable: { _ in true }
        )

        #expect(
            Preferences.shellOverrideStatusAnnouncement(
                from: inherited,
                to: invalid
            ) == invalid.statusAccessibilityLabel
        )
        #expect(
            Preferences.shellOverrideStatusAnnouncement(
                from: invalid,
                to: anotherInvalid
            ) == nil
        )
        #expect(
            Preferences.shellOverrideStatusAnnouncement(
                from: invalid,
                to: temporary
            ) == temporary.statusAccessibilityLabel
        )
        #expect(
            Preferences.shellOverrideStatusAnnouncement(
                from: missingA,
                to: missingB
            ) == nil
        )
        #expect(
            Preferences.shellOverrideStatusAnnouncement(
                from: invalid,
                to: active
            ) == active.statusAccessibilityLabel
        )
        #expect(
            Preferences.shellOverrideStatusAnnouncement(
                from: active,
                to: anotherActive
            ) == anotherActive.statusAccessibilityLabel
        )
        #expect(
            Preferences.shellOverrideStatusAnnouncement(
                from: active,
                to: inherited
            ) == inherited.statusAccessibilityLabel
        )
    }

    @Test("validated shell override path fails closed for relative temp and non-executable paths")
    func validatedShellOverridePathFailsClosed() {
        #expect(
            Preferences.validatedShellOverridePath(
                for: "bin/fish",
                isExecutable: { _ in true },
                resolvePath: { $0 }
            ) == nil
        )
        #expect(
            Preferences.validatedShellOverridePath(
                for: "/tmp/fish",
                isExecutable: { _ in true },
                resolvePath: { $0 }
            ) == nil
        )
        #expect(
            Preferences.validatedShellOverridePath(
                for: "/usr/local/bin/missing-shell",
                isExecutable: { _ in false },
                resolvePath: { $0 }
            ) == nil
        )
    }

    @Test("reset availability ignores surrounding whitespace")
    func resetAvailabilityIgnoresWhitespace() {
        let blank = Preferences.shellOverridePresentation(
            for: "   ",
            isExecutable: { _ in false }
        )
        let saved = Preferences.shellOverridePresentation(
            for: "  /opt/homebrew/bin/fish  ",
            isExecutable: { _ in true }
        )

        #expect(blank.canResetToLoginShell == false)
        #expect(saved.canResetToLoginShell)
    }

    @Test("plain-shell panes derive initial input from the validated override")
    func plainShellInitialInputUsesValidatedOverride() {
        #expect(
            HerminalSurfaceView.initialInputForNewSurface(
                command: nil,
                validatedShellPath: "/opt/homebrew/bin/fish"
            ) == "exec '/opt/homebrew/bin/fish' -l\n"
        )
        #expect(
            HerminalSurfaceView.initialInputForNewSurface(
                command: "",
                validatedShellPath: "/opt/homebrew/bin/fish"
            ) == "exec '/opt/homebrew/bin/fish' -l\n"
        )
    }

    @Test("explicit commands and missing overrides never get shell bootstrap input")
    func explicitCommandsSkipShellBootstrapInput() {
        var validatedPathLookupCount = 0

        #expect(
            HerminalSurfaceView.initialInputForNewSurface(
                command: "ssh user@example.com",
                validatedShellPath: {
                    validatedPathLookupCount += 1
                    return "/opt/homebrew/bin/fish"
                }()
            ) == nil
        )
        #expect(validatedPathLookupCount == 0)
        #expect(
            HerminalSurfaceView.initialInputForNewSurface(
                command: nil,
                validatedShellPath: nil
            ) == nil
        )
    }

    @Test("shell bootstrap input safely quotes paths for the handoff shell")
    func shellBootstrapInputQuotesPaths() {
        #expect(
            HerminalSurfaceView.initialInputForNewSurface(
                command: nil,
                validatedShellPath: "/Users/me/it's fish/bin/fish"
            ) == "exec '/Users/me/it'\"'\"'s fish/bin/fish' -l\n"
        )
    }
}
