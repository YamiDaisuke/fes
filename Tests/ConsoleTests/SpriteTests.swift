import Console
import GoldenImage
import Testing

private let cornerTriangle = 1
private let solid = 2

private func frameWithSpriteTiles(_ ppu: PPU) -> Framebuffer {
    var ppu = ppu
    for y in 0..<TileBank.tileSize {
        for x in 0..<TileBank.tileSize {
            ppu.spriteTiles.setPixel(tile: cornerTriangle, x: x, y: y, color: x + y < 7 ? x + 1 : 0)
            ppu.spriteTiles.setPixel(tile: solid, x: x, y: y, color: 7)
        }
    }
    var frame = Framebuffer()
    ppu.render(into: &frame)
    return frame
}

@Test func spriteFlipsMatchGolden() throws {
    var ppu = PPU()
    ppu.sprites[0] = Sprite(x: 40, y: 60, tile: cornerTriangle, palette: 7)
    ppu.sprites[1] = Sprite(x: 72, y: 60, tile: cornerTriangle, palette: 7, isFlippedHorizontally: true)
    ppu.sprites[2] = Sprite(x: 104, y: 60, tile: cornerTriangle, palette: 7, isFlippedVertically: true)
    ppu.sprites[3] = Sprite(
        x: 136, y: 60, tile: cornerTriangle, palette: 7, isFlippedHorizontally: true, isFlippedVertically: true
    )
    try expectFrameMatchesGolden(frameWithSpriteTiles(ppu), named: "sprite-flips")
}

@Test func spriteColorZeroShowsTheBackground() throws {
    var ppu = TestScene().ppu
    for i in 0..<8 {
        ppu.sprites[i] = Sprite(x: 4 + i * 23, y: 4 + i * 17, tile: cornerTriangle, palette: i)
    }
    try expectFrameMatchesGolden(frameWithSpriteTiles(ppu), named: "sprite-transparency")
}

@Test func spritesClipAtTheScreenEdges() throws {
    var ppu = PPU()
    ppu.sprites[0] = Sprite(x: -4, y: -4, tile: solid, palette: 4)
    ppu.sprites[1] = Sprite(x: 188, y: -4, tile: solid, palette: 5)
    ppu.sprites[2] = Sprite(x: -4, y: 140, tile: solid, palette: 6)
    ppu.sprites[3] = Sprite(x: 188, y: 140, tile: solid, palette: 7)
    ppu.sprites[4] = Sprite(x: -8, y: 60, tile: solid, palette: 7)
    ppu.sprites[5] = Sprite(x: 192, y: 60, tile: solid, palette: 7)
    try expectFrameMatchesGolden(frameWithSpriteTiles(ppu), named: "sprite-clipping")
}

@Test func spritePriorityAndTableOrderMatchGolden() throws {
    var ppu = TestScene().ppu
    ppu.sprites[0] = Sprite(x: 44, y: 12, tile: solid, palette: 1)
    ppu.sprites[1] = Sprite(x: 4, y: 4, tile: solid, palette: 2, isBehindBackground: true)
    ppu.sprites[2] = Sprite(x: 60, y: 40, tile: solid, palette: 3)
    ppu.sprites[3] = Sprite(x: 64, y: 44, tile: solid, palette: 4)
    ppu.sprites[4] = Sprite(x: 100, y: 40, tile: solid, palette: 5, isBehindBackground: true)
    ppu.sprites[5] = Sprite(x: 104, y: 44, tile: solid, palette: 7)
    try expectFrameMatchesGolden(frameWithSpriteTiles(ppu), named: "sprite-priority")
}

@Test func spritesBeyondSixteenPerScanlineAreDroppedInTableOrder() throws {
    var ppu = PPU()
    for i in 0..<20 {
        ppu.sprites[i] = Sprite(x: (19 - i) * 9, y: 40, tile: solid, palette: 7)
    }
    ppu.sprites[20] = Sprite(x: 184, y: 44, tile: solid, palette: 5)
    try expectFrameMatchesGolden(frameWithSpriteTiles(ppu), named: "sprite-scanline-limit")
}

@Test func extremeSpritePositionsWrapInsteadOfTrapping() {
    var extreme = PPU()
    extreme.sprites[0] = Sprite(x: Int.max, y: Int.min, tile: solid, palette: 7)
    var wrapped = PPU()
    wrapped.sprites[0] = Sprite(x: -1, y: 0, tile: solid, palette: 7)
    #expect(frameWithSpriteTiles(extreme) == frameWithSpriteTiles(wrapped))
}

private func rgba(_ frame: Framebuffer, x: Int, y: Int) -> [UInt8] {
    let offset = (y * Screen.width + x) * 4
    return Array(frame.rgba[offset..<(offset + 4)])
}

private func rgba(_ color: Color) -> [UInt8] {
    [color.red, color.green, color.blue, 255]
}

@Test func spritesDrawFromTheSpriteBanksNotTheBackgroundBanks() {
    var ppu = PPU()
    ppu.spritePalettes.setMasterIndex(40, palette: 0, index: 7)
    ppu.spritePalettes.setMasterIndex(41, palette: 0, index: 0)
    ppu.background[column: 2, row: 0] = Tilemap.Cell(tile: solid, palette: 0)
    ppu.sprites[0] = Sprite(x: 0, y: 0, tile: solid, palette: 0)
    let frame = frameWithSpriteTiles(ppu)
    #expect(rgba(frame, x: 0, y: 0) == rgba(MasterPalette.colors[40]))
    #expect(rgba(frame, x: 16, y: 0) == rgba(MasterPalette.colors[0]))
}

@Test func backgroundScrollDoesNotMoveSprites() {
    var unscrolled = PPU()
    unscrolled.sprites[0] = Sprite(x: 40, y: 60, tile: cornerTriangle, palette: 7)
    var scrolled = unscrolled
    scrolled.scrollX = 13
    scrolled.scrollY = 5
    #expect(frameWithSpriteTiles(scrolled) == frameWithSpriteTiles(unscrolled))
}
