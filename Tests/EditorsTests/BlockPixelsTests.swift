import Console
import Editors
import Testing

private func copyTile(_ source: Int, from sourceTiles: TileBank, to target: Int, in tiles: inout TileBank) {
    for y in 0..<TileBank.tileSize {
        for x in 0..<TileBank.tileSize {
            tiles.setPixel(tile: target, x: x, y: y, color: sourceTiles.colorIndex(tile: source, x: x, y: y))
        }
    }
}

private func numberedTiles() -> TileBank {
    var tiles = TileBank()
    for tile in 0..<TileBank.tileCount {
        for y in 0..<TileBank.tileSize {
            for x in 0..<TileBank.tileSize {
                tiles.setPixel(tile: tile, x: x, y: y, color: (tile + x * 3 + y * 5) % 8)
            }
        }
    }
    return tiles
}

@Test func flippingABlockHorizontallyMirrorsTheLeftTilesIntoTheRightOnes() {
    var tiles = TileBank()
    tiles.setPixel(tile: 0, x: 1, y: 2, color: 5)
    tiles.setPixel(tile: 16, x: 0, y: 7, color: 4)
    tiles.setPixel(tile: 2, x: 0, y: 0, color: 6)
    tiles.setPixel(tile: 32, x: 0, y: 0, color: 6)
    let block = TileBlock(selectedTile: 0, size: .two)

    tiles.paste(tiles.pixels(of: block).flippedHorizontally(), atSelectedTile: block.firstTile)

    var expected = TileBank()
    expected.setPixel(tile: 1, x: 6, y: 2, color: 5)
    expected.setPixel(tile: 17, x: 7, y: 7, color: 4)
    expected.setPixel(tile: 2, x: 0, y: 0, color: 6)
    expected.setPixel(tile: 32, x: 0, y: 0, color: 6)
    #expect(tiles == expected)
}

@Test func flippingABlockVerticallyMirrorsTheTopTilesIntoTheBottomOnes() {
    var tiles = TileBank()
    tiles.setPixel(tile: 0, x: 1, y: 2, color: 5)
    tiles.setPixel(tile: 1, x: 7, y: 0, color: 4)
    tiles.setPixel(tile: 2, x: 0, y: 0, color: 6)
    tiles.setPixel(tile: 32, x: 0, y: 0, color: 6)
    let block = TileBlock(selectedTile: 0, size: .two)

    tiles.paste(tiles.pixels(of: block).flippedVertically(), atSelectedTile: block.firstTile)

    var expected = TileBank()
    expected.setPixel(tile: 16, x: 1, y: 5, color: 5)
    expected.setPixel(tile: 17, x: 7, y: 7, color: 4)
    expected.setPixel(tile: 2, x: 0, y: 0, color: 6)
    expected.setPixel(tile: 32, x: 0, y: 0, color: 6)
    #expect(tiles == expected)
}

@Test func pastingATwoByTwoBlockAtTile255MovesInsideTheSheetWithEveryPixel() {
    let source = numberedTiles()
    let copied = source.pixels(of: TileBlock(selectedTile: 0, size: .two))
    var tiles = TileBank()

    tiles.paste(copied, atSelectedTile: 255)

    var expected = TileBank()
    for (from, to) in [(0, 238), (1, 239), (16, 254), (17, 255)] {
        copyTile(from, from: source, to: to, in: &expected)
    }
    #expect(tiles == expected)
}

@Test func pastingAOneByOneCopyWritesOnlyTheSelectedTile() {
    let source = numberedTiles()
    let copied = source.pixels(of: TileBlock(selectedTile: 5, size: .one))
    var tiles = TileBank()

    tiles.paste(copied, atSelectedTile: 255)

    var expected = TileBank()
    copyTile(5, from: source, to: 255, in: &expected)
    #expect(tiles == expected)
}
