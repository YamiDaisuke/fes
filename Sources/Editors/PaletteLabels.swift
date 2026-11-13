import Console
import Storage

extension Bank {
    var displayName: String {
        switch self {
        case .background: "Background"
        case .sprite: "Sprite"
        }
    }

    public var paletteHeading: String {
        "\(displayName) palettes"
    }

    public func mainColorHint(palette: Int, color: Int) -> String {
        if isTransparent(colorIndex: color) {
            return "Sprite color 0 is always transparent."
        }
        return "Choose a main color for \(displayName.lowercased()) palette \(palette), color \(color)."
    }
}

extension Cart {
    public func paletteEntryLabel(bank: Bank, palette: Int, index: Int) -> String {
        let entry = "\(bank.displayName) palette \(palette), color \(index)"
        if bank.isTransparent(colorIndex: index) {
            return "\(entry): transparent"
        }
        let mainIndex = palettes(in: bank).mainPaletteIndex(palette: palette, index: index)
        return "\(entry): main color \(mainIndex), \(mainPalette[mainIndex].hexCode)"
    }

    public func mainColorLabel(_ mainIndex: Int) -> String {
        "Main color \(mainIndex), \(mainPalette[mainIndex].hexCode)"
    }
}
