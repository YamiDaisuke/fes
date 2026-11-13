import Editors
import GoldenImage
import Testing

@Test func editAreaShowsTheTileWithAPixelGridAndCheckeredColorZero() throws {
    let cart = cartWithPatternTiles()
    let layout = editAreaLayout(fittingWidth: 57, height: 57)
    let image = editAreaImage(
        tiles: cart.tiles(in: .sprite),
        tile: 17,
        colors: cart.previewColors(bank: .sprite, palette: 2),
        layout: layout,
        cursor: nil
    )
    try expectImageMatchesGolden(
        rgba: image.rgba, width: image.width, height: image.height, named: "edit-area-sprite-palette-2-tile-17")
}

@Test func editAreaRingsTheCursorPixel() throws {
    let cart = cartWithPatternTiles()
    let layout = editAreaLayout(fittingWidth: 57, height: 57)
    let image = editAreaImage(
        tiles: cart.tiles(in: .sprite),
        tile: 17,
        colors: cart.previewColors(bank: .sprite, palette: 2),
        layout: layout,
        cursor: ArtPoint(x: 3, y: 2)
    )
    try expectImageMatchesGolden(
        rgba: image.rgba, width: image.width, height: image.height, named: "edit-area-sprite-palette-2-tile-17-cursor-3-2")
}
