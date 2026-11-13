import Console
import Storage

public enum Bank: String, CaseIterable {
    case background, sprite

    public func isTransparent(colorIndex: Int) -> Bool {
        self == .sprite && colorIndex == 0
    }
}

public enum ArtTool: String, CaseIterable {
    case pencil, picker, fill

    public var changesTiles: Bool {
        switch self {
        case .pencil, .fill: true
        case .picker: false
        }
    }
}

public struct ArtSelection: Equatable {
    public var bank = Bank.background
    public var previewPalette = 0
    public var tile = 0
    public var tool = ArtTool.pencil
    public var color = 1
    public var cursor = ArtPoint(x: 0, y: 0)
    public var blockSize = BlockSize.one

    public var block: TileBlock { TileBlock(selectedTile: tile, size: blockSize) }

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

    public func palettes(in bank: Bank) -> PaletteBank {
        switch bank {
        case .background: backgroundPalettes
        case .sprite: spritePalettes
        }
    }

    public mutating func setPalettes(_ palettes: PaletteBank, in bank: Bank) {
        switch bank {
        case .background: backgroundPalettes = palettes
        case .sprite: spritePalettes = palettes
        }
    }

    public func previewColors(bank: Bank, palette: Int) -> [Color?] {
        let bankPalettes = palettes(in: bank)
        return (0..<PaletteBank.colorsPerPalette).map { index in
            if bank.isTransparent(colorIndex: index) {
                return nil
            }
            return mainPalette[bankPalettes.mainPaletteIndex(palette: palette, index: index)]
        }
    }
}
