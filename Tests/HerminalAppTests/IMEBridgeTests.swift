import AppKit
import Foundation
import Testing
@testable import HerminalApp

/// Exercises the NSTextInputClient state machine that bridges macOS IMEs
/// (Vietnamese Telex / VNI, but also Korean, Japanese, Chinese, etc.) into
/// libghostty. Tests the SWIFT bridge — not the system IME itself; live
/// Telex composition is owner-tested per the 20-phrase checklist at
/// `docs/QA/vietnamese-ime-checklist.md` (M1-11).
///
/// The view's `surface` is nil here (no window is attached) so PTY-bound
/// side effects are no-ops by design. What we verify is the markedText /
/// accumulator state machine: that AppKit's IME callbacks update internal
/// state in the order a real composition cycle expects.
@MainActor
@Suite("IME bridge")
struct IMEBridgeTests {
    private var dummyApp: UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(bitPattern: 0xDEAD)!
    }

    private func freshView() -> HerminalSurfaceView {
        HerminalSurfaceView(app: dummyApp)
    }

    @Test("setMarkedText flips hasMarkedText and reports the marked range")
    func setMarkedTextFlipsState() {
        let view = freshView()
        #expect(view.hasMarkedText() == false)
        view.setMarkedText("tieesng", selectedRange: NSRange(), replacementRange: NSRange())
        #expect(view.hasMarkedText() == true)
        #expect(view.markedRange().length == "tieesng".utf16.count)
    }

    @Test("subsequent setMarkedText replaces the previous composition")
    func setMarkedTextReplaces() {
        let view = freshView()
        view.setMarkedText("tie", selectedRange: NSRange(), replacementRange: NSRange())
        view.setMarkedText("tieengs", selectedRange: NSRange(), replacementRange: NSRange())
        // The IME repeatedly updates marked text during a single composition;
        // the bridge must store the LATEST, not append.
        #expect(view.markedRange().length == "tieengs".utf16.count)
    }

    @Test("setMarkedText accepts both NSString and NSAttributedString")
    func setMarkedTextAcceptsBothShapes() {
        let view = freshView()
        // AppKit will hand the bridge either type depending on the IME and
        // macOS version — both must work.
        view.setMarkedText("plain", selectedRange: NSRange(), replacementRange: NSRange())
        #expect(view.hasMarkedText() == true)
        let attr = NSAttributedString(
            string: "tiếng",
            attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue]
        )
        view.setMarkedText(attr, selectedRange: NSRange(), replacementRange: NSRange())
        #expect(view.markedRange().length == "tiếng".utf16.count)
    }

    @Test("unmarkText clears the composition")
    func unmarkClears() {
        let view = freshView()
        view.setMarkedText("compose", selectedRange: NSRange(), replacementRange: NSRange())
        view.unmarkText()
        #expect(view.hasMarkedText() == false)
        #expect(view.markedRange().length == 0)
    }

    @Test("insertText after a composition ends marking")
    func insertEndsComposition() {
        let view = freshView()
        view.setMarkedText("tie", selectedRange: NSRange(), replacementRange: NSRange())
        view.insertText("tiếng", replacementRange: NSRange())
        // Commit must clear marked text — leaving it set would mean the IME
        // candidate would still appear underlined after commit.
        #expect(view.hasMarkedText() == false)
    }

    @Test("insertText ignores unsupported value types")
    func insertIgnoresOtherTypes() {
        let view = freshView()
        view.setMarkedText("x", selectedRange: NSRange(), replacementRange: NSRange())
        // 42 is neither String nor NSAttributedString — must not crash.
        view.insertText(42, replacementRange: NSRange())
        // Composition is untouched because the call no-ops.
        #expect(view.hasMarkedText() == true)
    }

    @Test("selectedRange is empty (libghostty owns the cursor)")
    func selectedRangeAlwaysEmpty() {
        let view = freshView()
        view.setMarkedText("x", selectedRange: NSRange(location: 0, length: 1),
                           replacementRange: NSRange())
        // The bridge doesn't track a Swift-side cursor — libghostty's grid is
        // the source of truth. selectedRange must stay empty so the IME asks
        // libghostty for cursor position via firstRect instead.
        #expect(view.selectedRange().length == 0)
    }

    @Test("validAttributesForMarkedText is empty (no styled preedit)")
    func validAttributesIsEmpty() {
        let view = freshView()
        // Returning attributes here would invite the IME to draw styled
        // overlays that don't match libghostty's underline preedit.
        #expect(view.validAttributesForMarkedText().isEmpty)
    }
}
