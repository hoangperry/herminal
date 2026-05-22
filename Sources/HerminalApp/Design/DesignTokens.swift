// DesignTokens — herminal design system.
// Premium dark aesthetic, Raycast/Linear-inspired.
//
// Scope: these tokens style the app CHROME (window, tab bar, panels,
// notes UI, agent dashboard). Terminal *content* colors are owned by
// libghostty's own theme and are not defined here.

import SwiftUI

enum HerminalDesign {

    // MARK: - Color Palette
    //
    // Dark-first. Values are sRGB, derived from OKLCH intent (noted in
    // comments) so the ladder stays perceptually even.
    enum Palette {
        // Surfaces — layered depth, cool near-black.
        static let surfaceBase = Color(red: 0.063, green: 0.067, blue: 0.078)      // oklch ~16% — window background
        static let surfaceElevated = Color(red: 0.090, green: 0.094, blue: 0.106)  // oklch ~20% — tab bar, side panels
        static let surfaceOverlay = Color(red: 0.122, green: 0.128, blue: 0.142)   // oklch ~24% — popovers, notes sheet

        // Text — emphasis ladder.
        static let textPrimary = Color(red: 0.93, green: 0.94, blue: 0.96)
        static let textSecondary = Color(red: 0.62, green: 0.64, blue: 0.69)
        static let textTertiary = Color(red: 0.40, green: 0.42, blue: 0.47)

        // Accent — herminal signature: teal-cyan (terminal heritage, modern feel).
        static let accent = Color(red: 0.32, green: 0.78, blue: 0.74)
        static let accentMuted = Color(red: 0.22, green: 0.46, blue: 0.45)

        // Hairline borders / dividers — opacity over surface.
        static let border = Color.white.opacity(0.08)
        static let divider = Color.white.opacity(0.05)

        // Semantic / agent status — used by the Month 3 agent dashboard.
        static let statusRunning = Color(red: 0.36, green: 0.72, blue: 1.00)
        static let statusIdle = Color(red: 0.55, green: 0.57, blue: 0.62)
        static let statusDone = Color(red: 0.40, green: 0.80, blue: 0.52)
        static let statusError = Color(red: 0.95, green: 0.45, blue: 0.42)
    }

    // MARK: - Typography
    //
    // UI text uses the macOS system font (SF Pro). The terminal grid font
    // is configured separately through libghostty.
    enum Typography {
        static let caption = Font.system(size: 11, weight: .medium)
        static let body = Font.system(size: 13, weight: .regular)
        static let bodyEmphasis = Font.system(size: 13, weight: .semibold)
        static let title = Font.system(size: 15, weight: .semibold)
        static let largeTitle = Font.system(size: 22, weight: .bold)
        /// Monospace for note snippets and command echoes in the chrome.
        static let mono = Font.system(size: 12, design: .monospaced)
    }

    // MARK: - Spacing (4-point grid)
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
    }

    // MARK: - Motion
    //
    // Durations in seconds. Keep motion quick — a terminal must feel instant.
    enum Motion {
        static let fast: Double = 0.12
        static let normal: Double = 0.22
    }
}
