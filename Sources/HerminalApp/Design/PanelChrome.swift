// PanelChrome — the shared furniture every sidebar panel puts around its
// content: the title strip at the top and the empty state underneath.
//
// The agent dashboard, the SSH host manager and the Claude session browser
// occupy the same slot and are toggled between, so any disagreement in
// their title tracking, leading rail or empty-state hierarchy reads as
// three different panels rather than three views of one sidebar. They each
// grew their own copy of that furniture; this is the single definition.

import SwiftUI

/// `@MainActor` because it builds SwiftUI views and reads
/// `TabBarView.barHeight`, both of which are main-actor isolated — same
/// isolation as every panel that calls in here.
@MainActor
enum PanelChrome {
    /// Leading rail shared by every panel's title and its rows.
    ///
    /// A panel's list carries `Spacing.sm` around the stack and another
    /// `Spacing.sm` inside each row, so row content starts at 16. The title
    /// sits on the same rail, which also keeps the header's trailing buttons
    /// off the panel edge.
    static let rail = HerminalDesign.Spacing.lg

    /// The title strip: uppercase label on the leading rail, caller-supplied
    /// trailing controls, one tab-bar height tall so it lines up with the
    /// tab strip across the window.
    static func header<Trailing: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: HerminalDesign.Spacing.xs) {
            Text(title)
                .font(HerminalDesign.Typography.caption)
                .tracking(HerminalDesign.Typography.headerTracking)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, rail)
        .frame(height: TabBarView.barHeight)
    }

    /// Panel-level empty state. The headline is `body` and the explanation
    /// `caption` — deliberately two sizes, so an empty panel still has a
    /// hierarchy to read instead of two equal grey lines.
    static func emptyState(_ headline: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xs) {
            Text(headline)
                .font(HerminalDesign.Typography.body)
                .foregroundStyle(HerminalDesign.Palette.textSecondary)
            // Parse the detail as markdown. Taking it as a `String` means
            // Text uses the plain initializer, not LocalizedStringKey, so a
            // code span reached the screen as literal backticks around the
            // word — "Run `claude` in any project" with the ticks showing,
            // which reads as a typo.
            Text((try? AttributedString(markdown: detail)) ?? AttributedString(detail))
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, rail)
        .padding(.vertical, HerminalDesign.Spacing.md)
    }
}
