import Console
import Storage

public enum Bank: String, CaseIterable {
    case background, sprite
}

public struct ArtSelection: Equatable {
    public var bank = Bank.background
    public var previewPalette = 0
    public var tile = 0

    public init() {}
}

extension Cart {
    public func tiles(in bank: Bank) -> TileBank {
        switch bank {
        case .background: backgroundTiles
        case .sprite: spriteTiles
        }
    }

    public func previewColors(bank: Bank, palette: Int) -> [Color?] {
        let palettes = bank == .background ? backgroundPalettes : spritePalettes
        return (0..<PaletteBank.colorsPerPalette).map { index in
            if bank == .sprite && index == 0 {
                return nil
            }
            return mainPalette[palettes.mainPaletteIndex(palette: palette, index: index)]
        }
    }
}
