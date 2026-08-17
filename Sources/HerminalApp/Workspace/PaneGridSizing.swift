// PaneGridSizing — keeps libghostty surfaces on complete terminal rows.
//
// AppKit lays views out in points while libghostty reports cell metrics in
// backing pixels. A fractional final row is rendered at the top edge, so each
// leaf pane removes that remainder and leaves it as balanced chrome gutter.

import CoreGraphics

enum PaneGridSizing {
    static func snapVertically(
        _ rect: CGRect,
        cellHeightPixels: UInt32,
        scale: CGFloat
    ) -> CGRect {
        guard rect.height > 0, cellHeightPixels > 0, scale > 0 else { return rect }

        let availablePixels = floor(rect.height * scale)
        let cellPixels = CGFloat(cellHeightPixels)
        let rows = floor(availablePixels / cellPixels)
        guard rows >= 1 else { return rect }

        let snappedHeight = rows * cellPixels / scale
        guard snappedHeight < rect.height else { return rect }

        // Pixel-align the lower gutter. Any odd backing pixel remains in the
        // upper gutter; the difference is at most one pixel.
        let remainderPixels = max(availablePixels - rows * cellPixels, 0)
        let lowerGutter = floor(remainderPixels / 2) / scale
        return CGRect(
            x: rect.minX,
            y: rect.minY + lowerGutter,
            width: rect.width,
            height: snappedHeight
        )
    }
}
