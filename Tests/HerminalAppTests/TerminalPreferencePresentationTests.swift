import Testing

@testable import HerminalApp

@Suite("Terminal preference presentation")
struct TerminalPreferencePresentationTests {
    @Test("font-size control reports its unit and new-tab scope")
    func fontSizeControlPresentation() {
        let presentation = Preferences.terminalFontSizePresentation(for: 13)

        #expect(presentation.visibleValue == "13")
        #expect(presentation.accessibilityLabel == "Terminal font size")
        #expect(presentation.accessibilityValue == "13 points")
        #expect(presentation.accessibilityHint == "Applies to new tabs.")
    }

    @Test("font-size control uses a singular unit and rounds persisted values")
    func fontSizeControlUsesSingularUnitAndRounds() {
        let singular = Preferences.terminalFontSizePresentation(for: 1)
        let rounded = Preferences.terminalFontSizePresentation(for: 13.6)

        #expect(singular.visibleValue == "1")
        #expect(singular.accessibilityValue == "1 point")
        #expect(rounded.visibleValue == "14")
        #expect(rounded.accessibilityValue == "14 points")
    }

    @Test("padding control reports pixels and new-tab scope")
    func paddingControlPresentation() {
        let presentation = Preferences.terminalPaddingPresentation(for: 4)

        #expect(presentation.visibleValue == "4px")
        #expect(presentation.accessibilityLabel == "Terminal padding")
        #expect(presentation.accessibilityValue == "4 pixels")
        #expect(presentation.accessibilityHint == "Applies to new tabs.")
    }

    @Test("padding uses a singular unit at one pixel")
    func paddingControlUsesSingularUnit() {
        let presentation = Preferences.terminalPaddingPresentation(for: 1)

        #expect(presentation.visibleValue == "1px")
        #expect(presentation.accessibilityValue == "1 pixel")
    }

    @Test("padding rounds persisted values before describing them")
    func paddingControlRoundsPersistedValues() {
        let presentation = Preferences.terminalPaddingPresentation(for: 4.6)

        #expect(presentation.visibleValue == "5px")
        #expect(presentation.accessibilityValue == "5 pixels")
    }
}
