import Console
import Editors
import GoldenImage
@testable import Storage
import Testing

@Test func labelUsesTheCartsMainPaletteForEachIndex() throws {
    var indices: [UInt8] = []
    for y in 0..<Screen.height {
        for x in 0..<Screen.width {
            indices.append(UInt8((y / 18) * 8 + x / 24))
        }
    }
    var mainPalette = MainPalette()
    mainPalette[0] = Color(rgb: 0xff00ff)
    let image = labelImage(CartLabel(mainPaletteIndices: indices), mainPalette: mainPalette)
    try expectImageMatchesGolden(
        rgba: image.rgba, width: image.width, height: image.height, named: "label-64-colors-magenta-0")
}
