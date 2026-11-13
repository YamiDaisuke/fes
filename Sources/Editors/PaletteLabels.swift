import Console
import Storage

extension Color {
    public var hexCode: String {
        "#" + [red, green, blue].map { component in
            let digits = String(component, radix: 16)
            return digits.count == 1 ? "0" + digits : digits
        }.joined()
    }
}

extension Cart {
    public func paletteEntryLabel(bank: Bank, palette: Int, index: Int) -> String {
        let bankName = switch bank {
        case .background: "Background"
        case .sprite: "Sprite"
        }
        let entry = "\(bankName) palette \(palette), color \(index)"
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
