import Console

public struct Cart: Equatable {
    public var name: String
    public internal(set) var codeFiles: [CodeFile]
    public var mainPalette = MainPalette()
    public var backgroundTiles = TileBank()
    public var spriteTiles = TileBank()
    public var backgroundPalettes = PaletteBank()
    public var spritePalettes = PaletteBank()
    public var background = Tilemap()

    public init(name: String, mainLua: String) {
        self.name = name
        codeFiles = [CodeFile(name: "main.lua", text: mainLua)]
    }

    public var mainLua: String {
        get { codeFiles[0].text }
        set { codeFiles[0].text = newValue }
    }
}
