import Editors
import GoldenImage
import Testing

@Test func editAreaShowsTheTileWithAPixelGridAndCheckeredColorZero() throws {
    let cart = cartWithPatternTiles()
    let block = TileBlock(selectedTile: 17, size: .one)
    let layout = editAreaLayout(fittingWidth: 57, height: 57, block: block)
    let image = editAreaImage(
        tiles: cart.tiles(in: .sprite),
        block: block,
        colors: cart.previewColors(bank: .sprite, palette: 2),
        layout: layout,
        cursor: nil
    )
    try expectImageMatchesGolden(
        rgba: image.rgba, width: image.width, height: image.height, named: "edit-area-sprite-palette-2-tile-17")
}

@Test func editAreaRingsTheCursorPixel() throws {
    let cart = cartWithPatternTiles()
    let block = TileBlock(selectedTile: 17, size: .one)
    let layout = editAreaLayout(fittingWidth: 57, height: 57, block: block)
    let image = editAreaImage(
        tiles: cart.tiles(in: .sprite),
        block: block,
        colors: cart.previewColors(bank: .sprite, palette: 2),
        layout: layout,
        cursor: ArtPoint(x: 3, y: 2)
    )
    try expectImageMatchesGolden(
        rgba: image.rgba, width: image.width, height: image.height, named: "edit-area-sprite-palette-2-tile-17-cursor-3-2")
}

@Test func editAreaShowsTheWholeBlockWithLighterLinesBetweenTiles() throws {
    let cart = cartWithPatternTiles()
    let block = TileBlock(selectedTile: 17, size: .two)
    let layout = editAreaLayout(fittingWidth: 97, height: 97, block: block)
    let image = editAreaImage(
        tiles: cart.tiles(in: .background),
        block: block,
        colors: cart.previewColors(bank: .background, palette: 0),
        layout: layout,
        cursor: nil
    )
    try expectImageMatchesGolden(
        rgba: image.rgba, width: image.width, height: image.height, named: "edit-area-background-palette-0-block-2-tile-17")
}
