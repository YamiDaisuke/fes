import Console
import Storage

public struct CartArt: Equatable {
    public var mainPalette: MainPalette
    public var backgroundTiles: TileBank
    public var spriteTiles: TileBank
    public var backgroundPalettes: PaletteBank
    public var spritePalettes: PaletteBank

    public init(
        mainPalette: MainPalette, backgroundTiles: TileBank, spriteTiles: TileBank,
        backgroundPalettes: PaletteBank, spritePalettes: PaletteBank
    ) {
        self.mainPalette = mainPalette
        self.backgroundTiles = backgroundTiles
        self.spriteTiles = spriteTiles
        self.backgroundPalettes = backgroundPalettes
        self.spritePalettes = spritePalettes
    }
}

extension Cart {
    public var art: CartArt {
        get {
            CartArt(
                mainPalette: mainPalette, backgroundTiles: backgroundTiles, spriteTiles: spriteTiles,
                backgroundPalettes: backgroundPalettes, spritePalettes: spritePalettes)
        }
        set {
            mainPalette = newValue.mainPalette
            backgroundTiles = newValue.backgroundTiles
            spriteTiles = newValue.spriteTiles
            backgroundPalettes = newValue.backgroundPalettes
            spritePalettes = newValue.spritePalettes
        }
    }
}
