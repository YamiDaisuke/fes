public struct PPU {
    public var tiles = TileBank()
    public var palettes = PaletteBank()
    public var background = Tilemap()
    public var scrollX = 0
    public var scrollY = 0

    public init() {}

    public func render(into framebuffer: inout Framebuffer) {
        let mapWidthMask = Tilemap.columns * TileBank.tileSize - 1
        let mapHeightMask = Tilemap.rows * TileBank.tileSize - 1
        let wrappedScrollX = scrollX & mapWidthMask
        let wrappedScrollY = scrollY & mapHeightMask
        for y in 0..<Screen.height {
            for x in 0..<Screen.width {
                let mapX = (x + wrappedScrollX) & mapWidthMask
                let mapY = (y + wrappedScrollY) & mapHeightMask
                framebuffer.setPixel(x: x, y: y, to: backgroundColor(mapX: mapX, mapY: mapY))
            }
        }
    }

    private func backgroundColor(mapX: Int, mapY: Int) -> Color {
        let size = TileBank.tileSize
        let cell = background[column: mapX / size, row: mapY / size]
        let index = tiles.colorIndex(tile: cell.tile, x: mapX % size, y: mapY % size)
        return palettes.color(palette: cell.palette, index: index)
    }
}
