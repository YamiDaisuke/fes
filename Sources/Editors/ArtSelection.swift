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

    func palettes(in bank: Bank) -> PaletteBank {
        switch bank {
        case .background: backgroundPalettes
        case .sprite: spritePalettes
        }
    }

    public func previewColors(bank: Bank, palette: Int) -> [Color?] {
        let bankPalettes = palettes(in: bank)
        return (0..<PaletteBank.colorsPerPalette).map { index in
            if bank == .sprite && index == 0 {
                return nil
            }
            return mainPalette[bankPalettes.mainPaletteIndex(palette: palette, index: index)]
        }
    }
}
