import Testing
@testable import HerminalApp

@Suite("HerminalDesign theme resolution")
struct ThemeResolutionTests {
    @Test("explicit themes ignore the system appearance")
    func explicitThemesWin() {
        #expect(HerminalDesign.resolvedTheme(preference: .dark, systemIsDark: false) == .dark)
        #expect(HerminalDesign.resolvedTheme(preference: .light, systemIsDark: true) == .light)
    }

    @Test("Follow System tracks both system appearances")
    func systemThemeTracksAppearance() {
        #expect(HerminalDesign.resolvedTheme(preference: .system, systemIsDark: true) == .dark)
        #expect(HerminalDesign.resolvedTheme(preference: .system, systemIsDark: false) == .light)
    }
}
