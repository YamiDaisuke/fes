import Editors
import Testing

@Test func blockPixelsMapToTheirTileAndPixelAcrossTileBorders() {
    let block = TileBlock(selectedTile: 17, size: .two)
    #expect(block.tileAndPixel(at: ArtPoint(x: 9, y: 0)) == (18, 1, 0))
    #expect(block.tileAndPixel(at: ArtPoint(x: 0, y: 8)) == (33, 0, 0))
    #expect(block.tileAndPixel(at: ArtPoint(x: 15, y: 15)) == (34, 7, 7))
}

@Test func blockAtTheSheetEdgeShiftsInsideAndKeepsTheSelectedTile() {
    #expect(TileBlock(selectedTile: 15, size: .two).tiles == [14, 15, 30, 31])
    #expect(TileBlock(selectedTile: 255, size: .four).firstTile == 204)
    #expect(TileBlock(selectedTile: 255, size: .four).tiles.last == 255)
    #expect(TileBlock(selectedTile: 240, size: .two).firstTile == 224)
}

@Test func oneByOneBlockIsTheSelectedTile() {
    #expect(TileBlock(selectedTile: 255, size: .one).tiles == [255])
    #expect(TileBlock(selectedTile: 15, size: .one).tiles == [15])
}
