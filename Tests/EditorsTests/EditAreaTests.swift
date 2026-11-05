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
        layout: layout
    )
    try expectImageMatchesGolden(
        rgba: image.rgba, width: image.width, height: image.height, named: "edit-area-sprite-palette-2-tile-17")
}
