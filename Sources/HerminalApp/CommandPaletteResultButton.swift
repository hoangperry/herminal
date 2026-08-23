import SwiftUI

struct CommandPaletteResultButton: View {
    let action: CommandPaletteAction
    let accessibility: CommandPaletteView.RowAccessibilityPresentation
    let isSelected: Bool
    let isFocused: Bool
    let onRun: () -> Void

    @State private var isHovered = false

    private var chrome: CommandPaletteView.RowChromePresentation {
        CommandPaletteView.rowChromePresentation(
            isSelected: isSelected,
            isHovered: isHovered,
            isFocused: isFocused
        )
    }

    var body: some View {
        Button(action: onRun) {
            HStack(spacing: 10) {
                Image(systemName: action.icon)
                    .font(.system(size: 13))
                    .foregroundColor(
                        chrome.isEmphasized
                            ? HerminalDesign.Palette.accent
                            : HerminalDesign.Palette.textSecondary
                    )
                    .frame(width: 18, alignment: .center)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(action.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(HerminalDesign.Palette.textPrimary)
                    if let subtitle = action.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(HerminalDesign.Palette.textTertiary)
                    }
                }
                Spacer(minLength: 0)
                if let shortcut = action.shortcutDisplay {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(HerminalDesign.Palette.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                                .fill(HerminalDesign.Palette.surfaceOverlay)
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(rowFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        chrome.showsFocusStroke
                            ? HerminalDesign.Palette.accent.opacity(0.55)
                            : .clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onKeyPress(.return) {
            onRun()
            return .handled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility.label)
        .accessibilityValue(ifPresent: accessibility.value)
        .accessibilityHint(accessibility.hint)
        .accessibilityAddTraits(accessibility.isSelected ? .isSelected : [])
    }

    private var rowFill: Color {
        if isSelected || isFocused {
            return HerminalDesign.Palette.accent.opacity(0.16)
        }
        return isHovered ? HerminalDesign.Palette.surfaceOverlay : .clear
    }
}

private extension View {
    @ViewBuilder
    func accessibilityValue(ifPresent value: String?) -> some View {
        if let value {
            accessibilityValue(value)
        } else {
            self
        }
    }
}
