public struct TestScene {
    public private(set) var ppu = PPU()

    public init() {
        for tile in 0..<8 {
            for y in 0..<8 {
                for x in 0..<8 {
                    let isGridLine = x == 0 || y == 0
                    let color = isGridLine ? 0 : (x < y ? tile : 7 - tile)
                    ppu.backgroundTiles.setPixel(tile: tile, x: x, y: y, color: color)
                }
            }
        }
        for row in 0..<Tilemap.rows {
            for column in 0..<Tilemap.columns {
                ppu.background[column: column, row: row] = Tilemap.Cell(tile: column / 4, palette: row / 4)
            }
        }
    }

    public mutating func render(frame: Int, into framebuffer: inout Framebuffer) {
        ppu.scrollX = frame
        ppu.scrollY = frame
        ppu.render(into: &framebuffer)
    }
}
