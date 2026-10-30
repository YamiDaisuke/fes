import Console
import Testing

@Test func cellCoordinatesWrapAtThirtyTwo() {
    var map = Tilemap()
    map[column: -1, row: 32] = Tilemap.Cell(tile: 9, palette: 2)
    #expect(map[column: 31, row: 0] == Tilemap.Cell(tile: 9, palette: 2))
    #expect(map[column: 63, row: -32] == Tilemap.Cell(tile: 9, palette: 2))
    #expect(map[column: 30, row: 0] == Tilemap.Cell(tile: 0, palette: 0))
}

@Test func cellTileAndPaletteWrapToTheirBitWidths() {
    var map = Tilemap()
    map[column: 0, row: 0] = Tilemap.Cell(tile: 257, palette: 9)
    #expect(map[column: 0, row: 0] == Tilemap.Cell(tile: 1, palette: 1))
    map[column: 0, row: 0] = Tilemap.Cell(tile: -1, palette: -1)
    #expect(map[column: 0, row: 0] == Tilemap.Cell(tile: 255, palette: 7))
}
