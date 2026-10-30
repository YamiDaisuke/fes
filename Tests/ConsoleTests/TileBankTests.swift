import Console
import Testing

private let blankRow = [0, 0, 0, 0, 0, 0, 0, 0]

@Test func newBankDecodesToColorZero() {
    #expect(TileBank().colorIndices(tile: 0, y: 0) == blankRow)
}

@Test func rowDecodesPixelsLeftToRight() {
    var bank = TileBank()
    for x in 0..<8 {
        bank.setPixel(tile: 1, x: x, y: 2, color: x)
    }
    #expect(bank.colorIndices(tile: 1, y: 2) == [0, 1, 2, 3, 4, 5, 6, 7])
}

@Test func overwritingAPixelClearsItsOldColor() {
    var bank = TileBank()
    bank.setPixel(tile: 0, x: 4, y: 0, color: 7)
    bank.setPixel(tile: 0, x: 4, y: 0, color: 2)
    #expect(bank.colorIndices(tile: 0, y: 0)[4] == 2)
}

@Test func settingAPixelLeavesNeighboursUntouched() {
    var bank = TileBank()
    bank.setPixel(tile: 5, x: 3, y: 4, color: 6)
    #expect(bank.colorIndices(tile: 5, y: 4) == [0, 0, 0, 6, 0, 0, 0, 0])
    #expect(bank.colorIndices(tile: 5, y: 3) == blankRow)
    #expect(bank.colorIndices(tile: 5, y: 5) == blankRow)
    #expect(bank.colorIndices(tile: 4, y: 4) == blankRow)
    #expect(bank.colorIndices(tile: 6, y: 4) == blankRow)
}

@Test func colorAboveSevenKeepsItsLowThreeBits() {
    var bank = TileBank()
    bank.setPixel(tile: 0, x: 1, y: 0, color: 9)
    #expect(bank.colorIndices(tile: 0, y: 0) == [0, 1, 0, 0, 0, 0, 0, 0])
}

@Test func everyRowOfEveryTileHasItsOwnStorage() {
    func pattern(tile: Int, y: Int) -> [Int] {
        let rowNumber = tile * 8 + y
        return (0..<8).map { x in (rowNumber >> (3 * x)) & 0b111 }
    }
    var bank = TileBank()
    for tile in 0..<256 {
        for y in 0..<8 {
            for (x, color) in pattern(tile: tile, y: y).enumerated() {
                bank.setPixel(tile: tile, x: x, y: y, color: color)
            }
        }
    }
    for tile in 0..<256 {
        for y in 0..<8 {
            #expect(bank.colorIndices(tile: tile, y: y) == pattern(tile: tile, y: y))
        }
    }
}

@Test func tileAndRowIndicesWrap() {
    var bank = TileBank()
    bank.setPixel(tile: 256, x: 8, y: 8, color: 3)
    #expect(bank.colorIndices(tile: 0, y: 0)[0] == 3)
    bank.setPixel(tile: -1, x: -1, y: -1, color: 5)
    #expect(bank.colorIndices(tile: 255, y: 7)[7] == 5)
}
