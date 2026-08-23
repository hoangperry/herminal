import AppKit
import Testing

@testable import HerminalApp

@Suite("Pane divider interaction")
@MainActor
struct PaneDividerInteractionTests {
    @Test("vertical divider maps horizontal arrows and balance keys")
    func verticalKeyboardMapping() {
        #expect(PaneDividerView.adjustment(forKeyCode: 123, isVertical: true) == .decrease)
        #expect(PaneDividerView.adjustment(forKeyCode: 124, isVertical: true) == .increase)
        #expect(PaneDividerView.adjustment(forKeyCode: 125, isVertical: true) == nil)
        #expect(PaneDividerView.adjustment(forKeyCode: 126, isVertical: true) == nil)
        #expect(PaneDividerView.adjustment(forKeyCode: 36, isVertical: true) == .balance)
        #expect(PaneDividerView.adjustment(forKeyCode: 49, isVertical: true) == .balance)
    }

    @Test("horizontal divider maps vertical arrows in visual movement order")
    func horizontalKeyboardMapping() {
        #expect(PaneDividerView.adjustment(forKeyCode: 126, isVertical: false) == .decrease)
        #expect(PaneDividerView.adjustment(forKeyCode: 125, isVertical: false) == .increase)
        #expect(PaneDividerView.adjustment(forKeyCode: 123, isVertical: false) == nil)
        #expect(PaneDividerView.adjustment(forKeyCode: 124, isVertical: false) == nil)
    }

    @Test("keyboard adjustments step clamp and balance the split ratio")
    func targetRatioPolicy() {
        #expect(PaneDividerView.targetRatio(from: 0.50, adjustment: .decrease) == 0.45)
        #expect(PaneDividerView.targetRatio(from: 0.50, adjustment: .increase) == 0.55)
        #expect(PaneDividerView.targetRatio(from: 0.73, adjustment: .balance) == 0.50)
        #expect(
            PaneDividerView.targetRatio(from: LayoutNode.minRatio, adjustment: .decrease)
                == LayoutNode.minRatio
        )
        #expect(
            PaneDividerView.targetRatio(
                from: 1 - LayoutNode.minRatio,
                adjustment: .increase
            ) == 1 - LayoutNode.minRatio
        )
    }

    @Test("divider exposes native splitter accessibility semantics")
    func accessibilitySemantics() {
        let divider = PaneDividerView(frame: NSRect(x: 0, y: 0, width: 8, height: 200))
        divider.isVertical = true
        divider.ratio = 0.42

        #expect(divider.acceptsFirstResponder)
        #expect(divider.canBecomeKeyView)
        #expect(divider.isAccessibilityElement())
        #expect(divider.accessibilityRole() == .splitter)
        #expect(divider.accessibilityLabel() == "Pane divider")
        #expect(divider.accessibilityOrientation() == .vertical)
        #expect((divider.accessibilityValue() as? NSNumber)?.intValue == 42)
        #expect(divider.accessibilityValueDescription() == "42 percent")
        #expect((divider.accessibilityMinValue() as? NSNumber)?.intValue == 8)
        #expect((divider.accessibilityMaxValue() as? NSNumber)?.intValue == 92)
        #expect(divider.accessibilityHelp()?.contains("arrow keys") == true)
    }

    @Test("horizontal divider reports horizontal accessibility orientation")
    func horizontalAccessibilityOrientation() {
        let divider = PaneDividerView(frame: .zero)
        divider.isVertical = false

        #expect(divider.accessibilityOrientation() == .horizontal)
    }

    @Test("assistive increment and decrement actions reach the resize callback")
    func accessibilityAdjustmentActions() {
        let divider = PaneDividerView(frame: .zero)
        var adjustments: [PaneDividerView.Adjustment] = []
        divider.onAdjustment = { adjustments.append($0) }

        #expect(divider.accessibilityPerformIncrement())
        #expect(divider.accessibilityPerformDecrement())
        #expect(adjustments == [.increase, .decrease])
    }

    @Test("keyboard focus receives a visible highlight without hover or drag")
    func keyboardFocusHighlight() {
        #expect(!PaneDividerView.shouldHighlight(
            isPointerInside: false,
            isDragging: false,
            isKeyboardFocused: false
        ))
        #expect(PaneDividerView.shouldHighlight(
            isPointerInside: true,
            isDragging: false,
            isKeyboardFocused: false
        ))
        #expect(PaneDividerView.shouldHighlight(
            isPointerInside: false,
            isDragging: true,
            isKeyboardFocused: false
        ))
        #expect(PaneDividerView.shouldHighlight(
            isPointerInside: false,
            isDragging: false,
            isKeyboardFocused: true
        ))
    }
}
