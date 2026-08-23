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
    enum Adjustment: Equatable {
        case decrease
        case increase
        case balance
    }

    /// Width of the invisible grab area centred on the gap line.
    static let hitThickness: CGFloat = 8
    /// One keyboard or assistive-technology step, expressed as a share
    /// of this split's own extent.
    static let ratioStep: CGFloat = 0.05

    /// true → vertical split (panes side by side) → this is a vertical
    /// bar dragged horizontally. false → stacked panes, dragged
    /// vertically.
    var isVertical: Bool = true {
        didSet {
            window?.invalidateCursorRects(for: self)
            updateAccessibilityPresentation()
        }
    }

    /// First-child share of this split. WorkspaceView remains the source
    /// of truth; this mirror exists so VoiceOver can announce the divider
    /// position as a percentage.
    var ratio: CGFloat = 0.5 {
        didSet {
            updateAccessibilityPresentation()
            if ratio != oldValue {
                NSAccessibility.post(element: self, notification: .valueChanged)
            }
        }
    }

    /// Called on each drag step with the signed delta in points along
    /// the axis since the previous event (x for vertical split,
    /// y for horizontal). WorkspaceView owns the ratio math.
    var onDrag: ((CGFloat) -> Void)?
    /// Keyboard and VoiceOver adjustments use ratios directly so the step
    /// stays stable at every window size.
    var onAdjustment: ((Adjustment) -> Void)?

    private var lastLocation: NSPoint?
    private var isPointerInside = false {
        didSet { needsDisplay = true }
    }
    private var isKeyboardFocused = false {
        didSet { needsDisplay = true }
    }
    private var isHighlighted: Bool {
        Self.shouldHighlight(
            isPointerInside: isPointerInside,
            isDragging: lastLocation != nil,
            isKeyboardFocused: isKeyboardFocused
        )
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        focusRingType = .none
        updateAccessibilityPresentation()
    }

    required init?(coder: NSCoder) {
        fatalError("PaneDividerView does not support NSCoder")
    }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    static func adjustment(forKeyCode keyCode: UInt16, isVertical: Bool) -> Adjustment? {
        switch (keyCode, isVertical) {
        case (123, true), (126, false):
            return .decrease
        case (124, true), (125, false):
            return .increase
        case (36, _), (49, _), (76, _):
            return .balance
        default:
            return nil
        }
    }

    static func targetRatio(from current: CGFloat, adjustment: Adjustment) -> CGFloat {
        let proposed: CGFloat = switch adjustment {
        case .decrease: current - ratioStep
        case .increase: current + ratioStep
        case .balance: 0.5
        }
        return min(max(proposed, LayoutNode.minRatio), 1 - LayoutNode.minRatio)
    }

    static func shouldHighlight(
        isPointerInside: Bool,
        isDragging: Bool,
        isKeyboardFocused: Bool
    ) -> Bool {
        isPointerInside || isDragging || isKeyboardFocused
    }

    // Transparent until hover/drag so the container's divider colour
    // shows through the gap underneath.
    override func draw(_ dirtyRect: NSRect) {
        guard isHighlighted else { return }
        let opacity: CGFloat = isKeyboardFocused ? 0.95 : 0.55
        NSColor(HerminalDesign.Palette.accent).withAlphaComponent(opacity).setFill()
        // Draw a 2 px line down the centre of the hit area so the
        // highlight reads as the divider, not the whole 8 px strip.
        let lineThickness: CGFloat = isKeyboardFocused ? 3 : 2
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

    override func mouseEntered(with event: NSEvent) { isPointerInside = true }
    override func mouseExited(with event: NSEvent) {
        isPointerInside = false
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        isKeyboardFocused = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }
        isKeyboardFocused = false
        return true
    }

    override func keyDown(with event: NSEvent) {
        let commandModifiers = event.modifierFlags.intersection([.command, .control, .option])
        guard commandModifiers.isEmpty,
              let adjustment = Self.adjustment(
                  forKeyCode: event.keyCode,
                  isVertical: isVertical
              ), perform(adjustment) else {
            super.keyDown(with: event)
            return
        }
    }

    override func accessibilityPerformIncrement() -> Bool { perform(.increase) }
    override func accessibilityPerformDecrement() -> Bool { perform(.decrease) }

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
        onAdjustment = nil
        super.removeFromSuperview()
    }

    override func mouseDown(with event: NSEvent) {
        lastLocation = event.locationInWindow
        needsDisplay = true
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
        isPointerInside = inside
        needsDisplay = true
    }

    private func perform(_ adjustment: Adjustment) -> Bool {
        guard let onAdjustment else { return false }
        onAdjustment(adjustment)
        return true
    }

    private func updateAccessibilityPresentation() {
        let percentage = Int((ratio * 100).rounded())
        setAccessibilityElement(true)
        setAccessibilityRole(.splitter)
        setAccessibilityLabel("Pane divider")
        setAccessibilityOrientation(isVertical ? .vertical : .horizontal)
        setAccessibilityValue(NSNumber(value: percentage))
        setAccessibilityValueDescription("\(percentage) percent")
        setAccessibilityMinValue(NSNumber(value: Int(LayoutNode.minRatio * 100)))
        setAccessibilityMaxValue(NSNumber(value: Int((1 - LayoutNode.minRatio) * 100)))
        setAccessibilityHelp(
            isVertical
                ? "Use the left and right arrow keys to resize adjacent panes. Press Return or Space to balance them."
                : "Use the up and down arrow keys to resize adjacent panes. Press Return or Space to balance them."
        )
    }
}
