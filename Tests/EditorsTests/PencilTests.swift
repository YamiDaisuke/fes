import Console
import Editors
import Testing

private func point(_ x: Int, _ y: Int) -> ArtPoint {
    ArtPoint(x: x, y: y)
}

private func paintedPoints(in tiles: TileBank, tile: Int, color: Int) -> [ArtPoint] {
    (0..<TileBank.tileSize).flatMap { y in
        (0..<TileBank.tileSize).compactMap { x in
            tiles.colorIndex(tile: tile, x: x, y: y) == color ? point(x, y) : nil
        }
    }
}

@Test func lineBetweenTwoPixelsHasNoGaps() {
    let ends = [point(0, 0), point(7, 2), point(2, 7), point(-3, 5), point(5, -4), point(-6, -1), point(3, 3)]
    for start in ends {
        for end in ends {
            let points = linePoints(from: start, to: end)
            #expect(points.first == start)
            #expect(points.last == end)
            for (previous, next) in zip(points, points.dropFirst()) {
                #expect(abs(next.x - previous.x) <= 1 && abs(next.y - previous.y) <= 1 && previous != next)
            }
        }
    }
}

@Test func horizontalVerticalAndDiagonalLinesPaintExactlyTheirPixels() {
    #expect(linePoints(from: point(5, 2), to: point(2, 2)) == [point(5, 2), point(4, 2), point(3, 2), point(2, 2)])
    #expect(linePoints(from: point(1, 0), to: point(1, 2)) == [point(1, 0), point(1, 1), point(1, 2)])
    #expect(linePoints(from: point(3, 3), to: point(1, 1)) == [point(3, 3), point(2, 2), point(1, 1)])
    #expect(linePoints(from: point(0, 0), to: point(3, 1)) == [point(0, 0), point(1, 0), point(2, 1), point(3, 1)])
}

@Test func lineLeavingTheTilePaintsOnlyInsidePixels() {
    var tiles = TileBank()
    tiles.paintLine(in: TileBlock(selectedTile: 4, size: .one), from: point(6, 3), to: point(12, 3), color: 5)
    #expect(paintedPoints(in: tiles, tile: 4, color: 5) == [point(6, 3), point(7, 3)])
    #expect(paintedPoints(in: tiles, tile: 5, color: 5) == [])
}

@Test func lineCrossingTheTileFromOutsidePaintsTheCrossedPixels() {
    var tiles = TileBank()
    tiles.paintLine(in: TileBlock(selectedTile: 0, size: .one), from: point(-3, -3), to: point(10, 10), color: 2)
    #expect(paintedPoints(in: tiles, tile: 0, color: 2) == (0..<8).map { point($0, $0) })
}

@Test func lineEntirelyOutsideTheTilePaintsNothing() {
    var tiles = TileBank()
    tiles.paintLine(in: TileBlock(selectedTile: 1, size: .one), from: point(-1, -5), to: point(-1, 12), color: 3)
    tiles.paintLine(in: TileBlock(selectedTile: 1, size: .one), from: point(8, 0), to: point(20, 7), color: 3)
    #expect(tiles == TileBank())
}

@Test func editAreaPositionsOutsideTheCanvasMapToPixelsOutsideTheTile() {
    let layout = editAreaLayout(fittingWidth: 57, height: 57, block: TileBlock(selectedTile: 0, size: .one))
    #expect(editAreaPixel(atX: -1, y: 0, in: layout) == point(-1, 0))
    #expect(editAreaPixel(atX: layout.side, y: 7, in: layout) == point(8, 0))
    #expect(editAreaPixel(atX: 7, y: 8, in: layout) == point(0, 1))
}

@Test func pickingOutsideTheTileGivesNoColor() {
    var tiles = TileBank()
    tiles.setPixel(tile: 9, x: 0, y: 0, color: 6)
    let block = TileBlock(selectedTile: 9, size: .one)
    #expect(colorIndex(at: point(0, 0), tiles: tiles, block: block) == 6)
    #expect(colorIndex(at: point(8, 0), tiles: tiles, block: block) == nil)
    #expect(colorIndex(at: point(0, -1), tiles: tiles, block: block) == nil)
}

@Test func lineCrossingATileBorderInABlockPaintsBothTilesAndNothingOutsideTheBlock() {
    var tiles = TileBank()
    tiles.paintLine(in: TileBlock(selectedTile: 0, size: .two), from: point(4, 3), to: point(20, 3), color: 5)
    #expect(paintedPoints(in: tiles, tile: 0, color: 5) == (4..<8).map { point($0, 3) })
    #expect(paintedPoints(in: tiles, tile: 1, color: 5) == (0..<8).map { point($0, 3) })
    #expect(paintedPoints(in: tiles, tile: 2, color: 5) == [])
}

@Test func pickingReadsTheTileUnderTheBlockPixel() {
    var tiles = TileBank()
    tiles.setPixel(tile: 17, x: 0, y: 0, color: 6)
    #expect(colorIndex(at: point(8, 8), tiles: tiles, block: TileBlock(selectedTile: 0, size: .two)) == 6)
}
