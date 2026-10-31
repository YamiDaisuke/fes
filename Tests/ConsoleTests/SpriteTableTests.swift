import Console
import Testing

@Test func scanlineSelectionKeepsTheFirstSixteenInTableOrder() {
    var table = SpriteTable()
    for i in 0..<20 {
        table[i] = Sprite(x: i, y: 10, tile: 0, palette: 0)
    }
    #expect(table.sprites(onScanline: 10).map(\.x) == Array(0..<16))
}

@Test func hiddenAndHorizontallyOffScreenSpritesDoNotCountTowardTheLimit() {
    var table = SpriteTable()
    table[1] = Sprite(x: -8, y: 10, tile: 0, palette: 0)
    table[3] = Sprite(x: 192, y: 10, tile: 0, palette: 0)
    for i in 4..<20 {
        table[i] = Sprite(x: i, y: 10, tile: 0, palette: 0)
    }
    #expect(table.sprites(onScanline: 10).map(\.x) == Array(4..<20))
}

@Test func partlyOffScreenSpritesCountTowardTheLimit() {
    var table = SpriteTable()
    table[0] = Sprite(x: -7, y: 10, tile: 0, palette: 0)
    table[1] = Sprite(x: 191, y: 10, tile: 0, palette: 0)
    #expect(table.sprites(onScanline: 10).map(\.x) == [-7, 191])
}

@Test func aSpriteCoversTheEightScanlinesFromItsY() {
    var table = SpriteTable()
    table[0] = Sprite(x: 0, y: -3, tile: 0, palette: 0)
    table[1] = Sprite(x: 1, y: 140, tile: 0, palette: 0)
    #expect(table.sprites(onScanline: 0).map(\.x) == [0])
    #expect(table.sprites(onScanline: 4).map(\.x) == [0])
    #expect(table.sprites(onScanline: 5).isEmpty)
    #expect(table.sprites(onScanline: 139).isEmpty)
    #expect(table.sprites(onScanline: 143).map(\.x) == [1])
}

@Test func tableIndexAndSpriteFieldsWrap() {
    var table = SpriteTable()
    table[64] = Sprite(x: 65536 + 5, y: 40000, tile: 257, palette: 9)
    #expect(table[0] == Sprite(x: 5, y: -25536, tile: 1, palette: 1))
    table[-1] = Sprite(x: 0, y: 0, tile: 0, palette: 0)
    #expect(table[63] == Sprite(x: 0, y: 0, tile: 0, palette: 0))
    table[63] = nil
    #expect(table[-1] == nil)
}
