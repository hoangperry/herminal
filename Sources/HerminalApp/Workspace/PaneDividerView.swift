// PaneDividerView — draggable handle between two split panes.
//
// Overlays the 1 px gap between panes with a wider (transparent) hit
// target so the divider is grabbable without stealing pane space. Shows
// the platform resize cursor on hover and a faint accent highlight while
// dragging. Reports the drag as a signed point delta along the split
// axis; WorkspaceView converts that to a ratio and mutates the tab.
// (v0.3.3 polish wave slice 4.)

import AppKit
import SwiftUI

final class PaneDividerView: NSView {
    /// Width of the invisible grab area centred on the gap line.
    static let hitThickness: CGFloat = 8

    /// true → vertical split (panes side by side) → this is a vertical
    /// bar dragged horizontally. false → stacked panes, dragged
    /// vertically.
    var isVertical: Bool = true {
        didSet { window?.invalidateCursorRects(for: self) }
    }

    /// Called on each drag step with the signed delta in points along
    /// the axis since the previous event (x for vertical split,
    /// y for horizontal). WorkspaceView owns the ratio math.
    var onDrag: ((CGFloat) -> Void)?

    private var lastLocation: NSPoint?
    private var isHighlighted = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("PaneDividerView does not support NSCoder")
    }

    // Transparent until hover/drag so the container's divider colour
    // shows through the gap underneath.
    override func draw(_ dirtyRect: NSRect) {
        guard isHighlighted else { return }
        NSColor(HerminalDesign.Palette.accent).withAlphaComponent(0.55).setFill()
        // Draw a 2 px line down the centre of the hit area so the
        // highlight reads as the divider, not the whole 8 px strip.
        let lineThickness: CGFloat = 2
        let rect: NSRect = isVertical
            ? NSRect(x: bounds.midX - lineThickness / 2, y: 0,
                     width: lineThickness, height: bounds.height)
            : NSRect(x: 0, y: bounds.midY - lineThickness / 2,
                     width: bounds.width, height: lineThickness)
        rect.fill()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: isVertical ? .resizeLeftRight : .resizeUpDown)
    }

    override func mouseEntered(with event: NSEvent) { isHighlighted = true }
    override func mouseExited(with event: NSEvent) {
        if lastLocation == nil { isHighlighted = false }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        ))
    }

    // An NSTrackingArea retains its `owner`, so `owner: self` forms a
    // self-cycle (view → trackingArea → view) that survives
    // `removeFromSuperview` and leaks every divider WorkspaceView rebuilds
    // on each split/resize. Drop the tracking areas as the view leaves the
    // hierarchy to break it. (v0.4.3 review HIGH-3.)
    override func removeFromSuperview() {
        trackingAreas.forEach(removeTrackingArea)
        onDrag = nil
        super.removeFromSuperview()
    }

    override func mouseDown(with event: NSEvent) {
        lastLocation = event.locationInWindow
        isHighlighted = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let last = lastLocation else { return }
        let now = event.locationInWindow
        let delta = isVertical ? (now.x - last.x) : (now.y - last.y)
        lastLocation = now
        if delta != 0 { onDrag?(delta) }
    }

    override func mouseUp(with event: NSEvent) {
        lastLocation = nil
        // Drop the highlight unless the pointer is still hovering.
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        isHighlighted = inside
    }
}
