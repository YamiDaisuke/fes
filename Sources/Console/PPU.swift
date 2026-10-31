public struct PPU {
    public var backgroundTiles = TileBank()
    public var backgroundPalettes = PaletteBank()
    public var spriteTiles = TileBank()
    public var spritePalettes = PaletteBank()
    public var background = Tilemap()
    public var sprites = SpriteTable()
    public var scrollX = 0
    public var scrollY = 0

    public init() {}

    public func render(into framebuffer: inout Framebuffer) {
        for y in 0..<Screen.height {
            let backgroundIndices = drawBackground(scanline: y, into: &framebuffer)
            drawSprites(scanline: y, over: backgroundIndices, into: &framebuffer)
        }
    }

    private func drawBackground(scanline y: Int, into framebuffer: inout Framebuffer) -> [Int] {
        let size = TileBank.tileSize
        let mapWidthMask = Tilemap.columns * size - 1
        let mapHeightMask = Tilemap.rows * size - 1
        let wrappedScrollX = scrollX & mapWidthMask
        let wrappedScrollY = scrollY & mapHeightMask
        let mapY = (y + wrappedScrollY) & mapHeightMask
        var colorIndices: [Int] = []
        for x in 0..<Screen.width {
            let mapX = (x + wrappedScrollX) & mapWidthMask
            let cell = background[column: mapX / size, row: mapY / size]
            let index = backgroundTiles.colorIndex(tile: cell.tile, x: mapX % size, y: mapY % size)
            framebuffer.setPixel(x: x, y: y, to: backgroundPalettes.color(palette: cell.palette, index: index))
            colorIndices.append(index)
        }
        return colorIndices
    }

    private func drawSprites(scanline y: Int, over backgroundIndices: [Int], into framebuffer: inout Framebuffer) {
        let onScanline = sprites.sprites(onScanline: y)
        let behind = onScanline.filter { $0.isBehindBackground }
        let front = onScanline.filter { !$0.isBehindBackground }
        let backToFront = behind.reversed() + front.reversed()
        let lastPixel = TileBank.tileSize - 1
        for sprite in backToFront {
            let rowFromTop = y - sprite.y
            let row = sprite.isFlippedVertically ? lastPixel - rowFromTop : rowFromTop
            for column in 0...lastPixel {
                let x = sprite.x + column
                if x < 0 || x >= Screen.width { continue }
                if sprite.isBehindBackground && backgroundIndices[x] != 0 { continue }
                let tileX = sprite.isFlippedHorizontally ? lastPixel - column : column
                let index = spriteTiles.colorIndex(tile: sprite.tile, x: tileX, y: row)
                if index == 0 { continue }
                framebuffer.setPixel(x: x, y: y, to: spritePalettes.color(palette: sprite.palette, index: index))
            }
        }
    }
}
