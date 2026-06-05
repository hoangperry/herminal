// PaneNavigation — spatial focus movement between panes.
//
// With recursive split trees (v0.5) a tab can hold an arbitrary nesting
// of panes, so "cycle to the next pane" isn't enough — you want to move
// focus the way it looks: left / right / up / down. This is the tmux
// `select-pane -L/-R/-U/-D` model, done geometrically on the laid-out
// frames so it's correct for any tree shape.
//
// Pure + frame-based, so it unit-tests without a view or libghostty.
// Coordinates are AppKit's (origin bottom-left): "up" is +y.

import CoreGraphics
import Foundation

enum PaneDirection {
    case left, right, up, down
}

enum PaneNavigation {
    /// Float slop for treating two primary-axis distances as equal so the
    /// perpendicular tie-break can decide (e.g. two stacked panes sharing
    /// the same column edge).
    private static let epsilon: CGFloat = 0.5

    /// The pane to move focus to from `focused` in `direction`, or nil if
    /// none sits on that side. A candidate qualifies only if its centre is
    /// on the correct side AND its perpendicular extent overlaps the
    /// focused pane's (so it's genuinely adjacent in that band). Among
    /// qualifiers: nearest along the travel axis wins, ties broken by the
    /// pane whose centre is closest on the perpendicular axis.
    static func nearestPane(from focused: CGRect,
                            candidates: [(id: UUID, rect: CGRect)],
                            direction: PaneDirection) -> UUID? {
        let fx = focused.midX, fy = focused.midY
        var best: (id: UUID, primaryGap: CGFloat, perpGap: CGFloat)?

        for candidate in candidates {
            let rect = candidate.rect
            let cx = rect.midX, cy = rect.midY
            let onSide: Bool
            let perpOverlap: CGFloat
            let primaryGap: CGFloat
            let perpCentreGap: CGFloat

            switch direction {
            case .left:
                onSide = cx < fx
                perpOverlap = overlap(focused.minY, focused.maxY, rect.minY, rect.maxY)
                primaryGap = fx - cx
                perpCentreGap = abs(cy - fy)
            case .right:
                onSide = cx > fx
                perpOverlap = overlap(focused.minY, focused.maxY, rect.minY, rect.maxY)
                primaryGap = cx - fx
                perpCentreGap = abs(cy - fy)
            case .up:
                onSide = cy > fy
                perpOverlap = overlap(focused.minX, focused.maxX, rect.minX, rect.maxX)
                primaryGap = cy - fy
                perpCentreGap = abs(cx - fx)
            case .down:
                onSide = cy < fy
                perpOverlap = overlap(focused.minX, focused.maxX, rect.minX, rect.maxX)
                primaryGap = fy - cy
                perpCentreGap = abs(cx - fx)
            }

            guard onSide, perpOverlap > 0 else { continue }

            if let current = best {
                let nearer = primaryGap < current.primaryGap - epsilon
                let tiedButCloser = primaryGap <= current.primaryGap + epsilon
                    && perpCentreGap < current.perpGap
                if nearer || tiedButCloser {
                    best = (candidate.id, primaryGap, perpCentreGap)
                }
            } else {
                best = (candidate.id, primaryGap, perpCentreGap)
            }
        }
        return best?.id
    }

    private static func overlap(_ aMin: CGFloat, _ aMax: CGFloat,
                                _ bMin: CGFloat, _ bMax: CGFloat) -> CGFloat {
        max(0, min(aMax, bMax) - max(aMin, bMin))
    }
}
