import Console
import Testing

@Test func mainPaletteWrapsTheIndexOfAColorToSixBits() {
    var palette = MainPalette()
    palette[-1] = Color(rgb: 0x010203)
    #expect(palette[63] == Color(rgb: 0x010203))
    #expect(palette[64] == palette[0])
}
