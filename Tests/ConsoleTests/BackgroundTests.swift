import Console
import Testing

private func sceneFrame(scrollX: Int, scrollY: Int) -> Framebuffer {
    var ppu = PPU()
    for tile in 0..<8 {
        for y in 0..<8 {
            for x in 0..<8 {
                let isGridLine = x == 0 || y == 0
                let color = isGridLine ? 0 : (x < y ? tile : 7 - tile)
                ppu.tiles.setPixel(tile: tile, x: x, y: y, color: color)
            }
        }
    }
    for row in 0..<Tilemap.rows {
        for column in 0..<Tilemap.columns {
            ppu.background[column: column, row: row] = Tilemap.Cell(tile: column / 4, palette: row / 4)
        }
    }
    ppu.scrollX = scrollX
    ppu.scrollY = scrollY
    var frame = Framebuffer()
    ppu.render(into: &frame)
    return frame
}

@Test func unscrolledBackgroundMatchesGolden() throws {
    try expectFrameMatchesGolden(sceneFrame(scrollX: 0, scrollY: 0), named: "background-unscrolled")
}

@Test func scrolledBackgroundMatchesGolden() throws {
    try expectFrameMatchesGolden(sceneFrame(scrollX: 13, scrollY: 21), named: "background-scrolled")
}

@Test func backgroundWrapsAtTheMapEdges() throws {
    try expectFrameMatchesGolden(sceneFrame(scrollX: 200, scrollY: 180), named: "background-wrapping")
}

@Test func scrollingOnePixelRightShiftsTheFrameOnePixelLeft() {
    let unscrolled = sceneFrame(scrollX: 0, scrollY: 0).rgba
    let scrolled = sceneFrame(scrollX: 1, scrollY: 0).rgba
    let rowLength = Screen.width * 4
    for y in 0..<Screen.height {
        let row = y * rowLength
        #expect(scrolled[row..<(row + rowLength - 4)] == unscrolled[(row + 4)..<(row + rowLength)])
    }
}

@Test func negativeAndOversizedScrollWrapLikeTheirRemainder() {
    let remainder = sceneFrame(scrollX: 236, scrollY: 244)
    #expect(sceneFrame(scrollX: -20, scrollY: -12) == remainder)
    #expect(sceneFrame(scrollX: 492, scrollY: 500) == remainder)
}

@Test func extremeScrollWrapsInsteadOfOverflowing() {
    #expect(sceneFrame(scrollX: Int.max, scrollY: Int.max) == sceneFrame(scrollX: 255, scrollY: 255))
    #expect(sceneFrame(scrollX: Int.min, scrollY: Int.min) == sceneFrame(scrollX: 0, scrollY: 0))
}

@Test func framebufferStoresPixelsAsRGBARowMajor() {
    var frame = Framebuffer()
    frame.setPixel(x: 2, y: 1, to: Color(red: 10, green: 20, blue: 30))
    let offset = (1 * Screen.width + 2) * 4
    #expect(Array(frame.rgba[offset..<(offset + 4)]) == [10, 20, 30, 255])
}
