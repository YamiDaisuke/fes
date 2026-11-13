import Console
import Editors
import Testing

@Test func hexCodeKeepsLeadingZeros() {
    #expect(Color(rgb: 0x0d7185).hexCode == "#0d7185")
    #expect(Color(rgb: 0).hexCode == "#000000")
}

@Test func pickerValueInEitherCaseReadsAsTheSameColor() {
    #expect(Color(hexCode: "#49b893") == Color(rgb: 0x49b893))
    #expect(Color(hexCode: "#49B893") == Color(rgb: 0x49b893))
}

@Test(arguments: [0x000000, 0x0d7185, 0xc058cc, 0xffffff])
func hexCodeReadsBackAsTheSameColor(rgb: Int) {
    let color = Color(rgb: rgb)
    #expect(Color(hexCode: color.hexCode) == color)
}

@Test(arguments: [
    "", "#", "49b893", "#fff", "#49b89", "#49b8931", "#49b893ff", " #49b893", "#49b893 ", "#49b89g",
    "#+9b893", "#-9b893", "#４9b893", "color(display-p3 1 0 0)",
])
func pickerValuesThatAreNotSixHexDigitsAfterHashAreRefused(value: String) {
    #expect(Color(hexCode: value) == nil)
}
