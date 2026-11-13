import Console
import Storage

public enum Bank: String, CaseIterable {
    case background, sprite
}

public enum ArtTool: String, CaseIterable {
    case pencil, picker
}

public struct ArtSelection: Equatable {
    public var bank = Bank.background
    public var previewPalette = 0
    public var tile = 0
    public var tool = ArtTool.pencil
    public var color = 1

    public init() {}
}

extension Cart {
    public func tiles(in bank: Bank) -> TileBank {
        switch bank {
        case .background: backgroundTiles
        case .sprite: spriteTiles
        }
    }

    public mutating func setTiles(_ tiles: TileBank, in bank: Bank) {
        switch bank {
        case .background: backgroundTiles = tiles
        case .sprite: spriteTiles = tiles
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
