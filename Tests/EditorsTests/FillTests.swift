import Console
import Editors
import Testing

private func point(_ x: Int, _ y: Int) -> ArtPoint {
    ArtPoint(x: x, y: y)
}

private func tileColumn(_ tiles: TileBank, tile: Int, x: Int) -> [Int] {
    (0..<TileBank.tileSize).map { y in tiles.colorIndex(tile: tile, x: x, y: y) }
}

@Test func fillCrossesTileBordersInsideTheBlockAndStopsAtTheOutlineAndTheBlockEdge() {
    let block = TileBlock(selectedTile: 0, size: .two)
    var tiles = TileBank()
    tiles.paintLine(in: block, from: point(12, 0), to: point(12, 15), color: 1)

    tiles.fill(in: block, from: point(0, 0), color: 3)

    for tile in [0, 16] {
        #expect(tiles.pixels(of: TileBlock(selectedTile: tile, size: .one)).colors == Array(repeating: 3, count: 64))
    }
    for tile in [1, 17] {
        #expect((0...3).map { tileColumn(tiles, tile: tile, x: $0) } == Array(repeating: Array(repeating: 3, count: 8), count: 4))
        #expect(tileColumn(tiles, tile: tile, x: 4) == Array(repeating: 1, count: 8))
        #expect(tileColumn(tiles, tile: tile, x: 5) == Array(repeating: 0, count: 8))
    }
    for outside in [2, 18, 32, 33] {
        #expect(tiles.pixels(of: TileBlock(selectedTile: outside, size: .one)).colors == Array(repeating: 0, count: 64))
    }
}

@Test func fillDoesNotPassThroughADiagonalOnlyGap() {
    let block = TileBlock(selectedTile: 4, size: .one)
    var tiles = TileBank()
    tiles.paintLine(in: block, from: point(0, 7), to: point(7, 0), color: 1)

    tiles.fill(in: block, from: point(0, 0), color: 2)

    #expect(tiles.colorIndex(tile: 4, x: 6, y: 0) == 2)
    #expect(tiles.colorIndex(tile: 4, x: 1, y: 7) == 0)
    #expect(tiles.colorIndex(tile: 4, x: 7, y: 7) == 0)
}

@Test func fillWithTheRegionsOwnColorChangesNothing() {
    var tiles = TileBank()
    tiles.fill(in: TileBlock(selectedTile: 0, size: .four), from: point(5, 5), color: 0)
    #expect(tiles == TileBank())
}
