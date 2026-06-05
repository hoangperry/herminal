// PaneFocusRingView — the accent border around the focused pane.
//
// Once a tab holds more than one pane (and especially with v0.5.1
// directional focus movement), you need to see which pane the keyboard is
// going to. This overlay draws a thin accent outline over the focused
// pane's frame — border only, interior clear, so the terminal shows
// through. It's purely decorative: `hitTest` returns nil so it never
// intercepts a click or a divider drag meant for what's underneath.
//
// WorkspaceView owns a single instance, repositions it on every layout /
// focus change, and hides it when a tab has just one pane (no ambiguity).

import AppKit
import SwiftUI

final class PaneFocusRingView: NSView {
    static let lineWidth: CGFloat = 2

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("PaneFocusRingView does not support NSCoder")
    }

    // Mouse-transparent: clicks, drags and hovers pass straight through to
    // the terminal surface (and the divider handles) below.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        // Inset by half the line width so the full stroke sits inside the
        // pane's frame and stays visible even for edge-flush panes.
        let inset = Self.lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        guard rect.width > 0, rect.height > 0 else { return }
        let path = NSBezierPath(rect: rect)
        path.lineWidth = Self.lineWidth
        NSColor(HerminalDesign.Palette.accent).withAlphaComponent(0.9).setStroke()
        path.stroke()
    }
}
