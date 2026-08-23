import AppKit
import Testing

@testable import HerminalApp

@Suite("Terminal fallback context menu")
@MainActor
struct TerminalContextMenuPolicyTests {
    private var dummyApp: UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(bitPattern: 0xC0FFEE)!
    }

    private func freshView() -> HerminalSurfaceView {
        HerminalSurfaceView(app: dummyApp)
    }

    @Test("fallback context menu includes find in a stable task order")
    func stableItemOrder() {
        let menu = freshView().makeFallbackContextMenu()
        let tokens = menu.items.map { item in
            item.isSeparatorItem ? "<separator>" : item.title
        }

        #expect(tokens == [
            "Copy",
            "Paste",
            "Select All",
            "<separator>",
            "Find in Terminal…",
        ])
    }

    @Test("find action matches the existing workspace search entry point")
    func findActionUsesWorkspaceSelector() throws {
        let menu = freshView().makeFallbackContextMenu()
        let item = try #require(menu.items.first { $0.title == "Find in Terminal…" })

        #expect(item.action == #selector(WorkspaceView.findInScrollback(_:)))
        #expect(item.target == nil)
        #expect(item.keyEquivalent == "f")
        #expect(item.keyEquivalentModifierMask == .command)
    }

    @Test("clipboard and selection actions remain local to the terminal surface")
    func editActionsKeepSurfaceTarget() throws {
        let view = freshView()
        let menu = view.makeFallbackContextMenu()
        let localActions = [
            #selector(HerminalSurfaceView.copy(_:)),
            #selector(HerminalSurfaceView.paste(_:)),
            #selector(HerminalSurfaceView.selectAll(_:)),
        ]

        for action in localActions {
            let item = try #require(menu.items.first { $0.action == action })
            #expect(item.target === view)
        }
    }

    @Test("standard edit actions expose their familiar command shortcuts")
    func editActionsExposeShortcuts() throws {
        let menu = freshView().makeFallbackContextMenu()
        let expected: [(Selector, String)] = [
            (#selector(HerminalSurfaceView.copy(_:)), "c"),
            (#selector(HerminalSurfaceView.paste(_:)), "v"),
            (#selector(HerminalSurfaceView.selectAll(_:)), "a"),
        ]

        for (action, keyEquivalent) in expected {
            let item = try #require(menu.items.first { $0.action == action })
            #expect(item.keyEquivalent == keyEquivalent)
            #expect(item.keyEquivalentModifierMask == .command)
        }
    }

    @Test("local edit actions preserve their surface validation requirements")
    func editActionAvailability() {
        let copy = #selector(HerminalSurfaceView.copy(_:))
        let cut = #selector(HerminalSurfaceView.cut(_:))
        let paste = #selector(HerminalSurfaceView.paste(_:))
        let selectAll = #selector(HerminalSurfaceView.selectAll(_:))

        for action in [copy, cut, paste, selectAll] {
            #expect(!HerminalSurfaceView.editActionIsEnabled(
                action,
                hasSurface: false,
                hasSelection: true,
                hasPasteboardString: true
            ))
        }
        #expect(!HerminalSurfaceView.editActionIsEnabled(
            copy,
            hasSurface: true,
            hasSelection: false,
            hasPasteboardString: true
        ))
        #expect(HerminalSurfaceView.editActionIsEnabled(
            cut,
            hasSurface: true,
            hasSelection: true,
            hasPasteboardString: false
        ))
        #expect(!HerminalSurfaceView.editActionIsEnabled(
            paste,
            hasSurface: true,
            hasSelection: true,
            hasPasteboardString: false
        ))
        #expect(HerminalSurfaceView.editActionIsEnabled(
            paste,
            hasSurface: true,
            hasSelection: false,
            hasPasteboardString: true
        ))
        #expect(HerminalSurfaceView.editActionIsEnabled(
            selectAll,
            hasSurface: true,
            hasSelection: false,
            hasPasteboardString: false
        ))
    }
}
