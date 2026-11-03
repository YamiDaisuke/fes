import Console

public struct Cart: Equatable {
    public var name: String
    public var mainLua: String
    public var backgroundTiles = TileBank()
    public var spriteTiles = TileBank()
    public var backgroundPalettes = PaletteBank()
    public var spritePalettes = PaletteBank()
    public var background = Tilemap()

    public init(name: String, mainLua: String) {
        self.name = name
        self.mainLua = mainLua
    }
}
