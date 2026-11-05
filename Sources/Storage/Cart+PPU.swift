import Console

extension Cart {
    public var ppu: PPU {
        var ppu = PPU()
        ppu.mainPalette = mainPalette
        ppu.backgroundTiles = backgroundTiles
        ppu.spriteTiles = spriteTiles
        ppu.backgroundPalettes = backgroundPalettes
        ppu.spritePalettes = spritePalettes
        ppu.background = background
        return ppu
    }
}
