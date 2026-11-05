import Editors
import GoldenImage
import Testing

@Test func sheetTapsMapToTheTileUnderThem() {
    let layout = tileSheetLayout(fittingWidth: 273, height: 273)
    let insideTile17 = layout.origin(ofSquare: 1) + 3
    #expect(sheetTile(atX: insideTile17, y: insideTile17, in: layout) == 17)
    #expect(sheetTile(atX: layout.side - 1, y: layout.side - 1, in: layout) == 255)
    #expect(sheetTile(atX: layout.side, y: 0, in: layout) == nil)
    #expect(sheetTile(atX: 0, y: -1, in: layout) == nil)
}

@Test func spriteSheetDrawsColorZeroAsCheckerAndRingsTheSelectedTile() throws {
    let cart = cartWithPatternTiles()
    let layout = tileSheetLayout(fittingWidth: 273, height: 273)
    #expect(layout.zoom == 2)
    let image = tileSheetImage(
        tiles: cart.tiles(in: .sprite),
        colors: cart.previewColors(bank: .sprite, palette: 2),
        selectedTile: 17,
        layout: layout
    )
    try expectImageMatchesGolden(
        rgba: image.rgba, width: image.width, height: image.height, named: "sheet-sprite-palette-2-tile-17")
}

@Test func backgroundSheetDrawsColorZeroOpaqueAndRingsTheLastTile() throws {
    let cart = cartWithPatternTiles()
    let layout = tileSheetLayout(fittingWidth: 145, height: 145)
    #expect(layout.zoom == 1)
    let image = tileSheetImage(
        tiles: cart.tiles(in: .background),
        colors: cart.previewColors(bank: .background, palette: 0),
        selectedTile: 255,
        layout: layout
    )
    try expectImageMatchesGolden(
        rgba: image.rgba, width: image.width, height: image.height, named: "sheet-background-palette-0-tile-255")
}

@Test func sheetRingWrapsTileNumbersLikeTheTileBank() {
    let cart = cartWithPatternTiles()
    let layout = tileSheetLayout(fittingWidth: 145, height: 145)
    func sheet(selecting tile: Int) -> RGBAImage {
        tileSheetImage(
            tiles: cart.tiles(in: .background),
            colors: cart.previewColors(bank: .background, palette: 0),
            selectedTile: tile,
            layout: layout
        )
    }
    #expect(sheet(selecting: 256) == sheet(selecting: 0))
    #expect(sheet(selecting: -1) == sheet(selecting: 255))
}
