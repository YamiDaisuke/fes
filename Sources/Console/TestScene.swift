public struct TestScene {
    public private(set) var ppu = PPU()

    private let indicatorTile = 0
    private let heldPalette = 0
    private let pressedPalette = 1

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
        for y in 0..<8 {
            for x in 0..<8 {
                ppu.spriteTiles.setPixel(tile: indicatorTile, x: x, y: y, color: 7)
            }
        }
    }

    public mutating func render(frame: Int, input: Input, into framebuffer: inout Framebuffer) {
        ppu.scrollX = frame
        ppu.scrollY = frame
        for button in Button.allCases {
            let palette = input.wasPressedThisFrame(button) ? pressedPalette : heldPalette
            let indicator = Sprite(x: 50 + button.rawValue * 12, y: 8, tile: indicatorTile, palette: palette)
            ppu.sprites[button.rawValue] = input.isHeld(button) ? indicator : nil
        }
        ppu.render(into: &framebuffer)
    }
}
