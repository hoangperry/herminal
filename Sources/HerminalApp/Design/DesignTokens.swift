// DesignTokens — herminal design system.
// Premium dark aesthetic, Raycast/Linear-inspired.
//
// Scope: these tokens style the app CHROME (window, tab bar, panels,
// notes UI, agent dashboard). Terminal *content* colors are owned by
// libghostty's own theme and are not defined here.

import SwiftUI

enum HerminalDesign {

    // MARK: - Theme switching
    //
    // M9/C-light closes Q5-002: light theme variant. The runtime theme is
    // a settable static — every Palette accessor checks it and returns
    // the appropriate sRGB value. We keep the dark theme as default
    // (PRD: Raycast/Linear-style "premium dark"); the light theme exists
    // for users whose macOS appearance is set to Light and who want
    // herminal to follow. Auto-follow-system is post-MVP — for now the
    // owner toggles via Window menu (⌘⇧L).
    enum Theme: String, CaseIterable {
        case dark
        case light
    }

    /// `nonisolated(unsafe)`: read from any view-update path on the main
    /// thread; mutated only by the menu toggle, which is also main-thread.
    /// No cross-thread access possible (all UI is @MainActor).
    nonisolated(unsafe) static var currentTheme: Theme = .dark

    // MARK: - Color Palette
    //
    // Each token is a computed `Color` that branches on `currentTheme`.
    // Dark values were the M2 originals; light values were chosen so the
    // contrast ladder (primary > secondary > tertiary) reads the same and
    // the accent stays in the same hue family (just tonally lighter).
    enum Palette {
        // Surfaces — layered depth.
        static var surfaceBase: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color(red: 0.063, green: 0.067, blue: 0.078)
            case .light: return Color(red: 0.98, green: 0.98, blue: 0.99)
            }
        }
        static var surfaceElevated: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color(red: 0.090, green: 0.094, blue: 0.106)
            case .light: return Color(red: 0.96, green: 0.96, blue: 0.97)
            }
        }
        static var surfaceOverlay: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color(red: 0.122, green: 0.128, blue: 0.142)
            case .light: return Color(red: 0.93, green: 0.93, blue: 0.95)
            }
        }

        // Text — emphasis ladder. Light theme inverts the ladder direction.
        static var textPrimary: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color(red: 0.93, green: 0.94, blue: 0.96)
            case .light: return Color(red: 0.13, green: 0.14, blue: 0.16)
            }
        }
        static var textSecondary: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color(red: 0.62, green: 0.64, blue: 0.69)
            case .light: return Color(red: 0.36, green: 0.38, blue: 0.43)
            }
        }
        static var textTertiary: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color(red: 0.40, green: 0.42, blue: 0.47)
            case .light: return Color(red: 0.55, green: 0.57, blue: 0.62)
            }
        }

        // Accent — same hue, tonally adjusted per theme so it pops in both.
        static var accent: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color(red: 0.32, green: 0.78, blue: 0.74)
            case .light: return Color(red: 0.16, green: 0.55, blue: 0.51)
            }
        }
        static var accentMuted: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color(red: 0.22, green: 0.46, blue: 0.45)
            case .light: return Color(red: 0.55, green: 0.78, blue: 0.75)
            }
        }

        // Borders / dividers — neutral overlay that works in both.
        static var border: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color.white.opacity(0.08)
            case .light: return Color.black.opacity(0.10)
            }
        }
        static var divider: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color.white.opacity(0.05)
            case .light: return Color.black.opacity(0.06)
            }
        }

        // Semantic / agent status — same hues, slight desaturation for light
        // so they don't shout on a high-luminance background.
        static var statusRunning: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color(red: 0.36, green: 0.72, blue: 1.00)
            case .light: return Color(red: 0.22, green: 0.50, blue: 0.85)
            }
        }
        static var statusIdle: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color(red: 0.55, green: 0.57, blue: 0.62)
            case .light: return Color(red: 0.48, green: 0.50, blue: 0.55)
            }
        }
        static var statusDone: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color(red: 0.40, green: 0.80, blue: 0.52)
            case .light: return Color(red: 0.22, green: 0.62, blue: 0.36)
            }
        }
        static var statusError: Color {
            switch HerminalDesign.currentTheme {
            case .dark: return Color(red: 0.95, green: 0.45, blue: 0.42)
            case .light: return Color(red: 0.78, green: 0.28, blue: 0.26)
            }
        }
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
