import Console
@testable import Storage
import Testing

private func variedLabel() -> CartLabel {
    CartLabel(mainPaletteIndices: (0..<(Screen.width * Screen.height)).map { UInt8($0 * 7 % MainPalette.colorCount) })
}

private func labelLines() -> [String] {
    labelText(variedLabel()).split(separator: "\n").map(String.init)
}

private func labelRefusal(_ text: String) -> String? {
    var files = sampleCart().files
    files["label.hex"] = text
    do {
        _ = try Cart(files: files)
        return nil
    } catch {
        return error.description
    }
}

private func labelRefusal(changingLine line: Int, to newLine: String) -> String? {
    var lines = labelLines()
    lines[line - 1] = newLine
    return labelRefusal(lines.joined(separator: "\n") + "\n")
}

private func capturedIndex(of color: Color, in mainPalette: MainPalette = MainPalette()) -> UInt8 {
    var framebuffer = Framebuffer()
    framebuffer.setPixel(x: 5, y: 2, to: color)
    return CartLabel(framebuffer: framebuffer, mainPalette: mainPalette).mainPaletteIndices[2 * Screen.width + 5]
}

@Test func labelledCartSurvivesARoundTripThroughFilesAFesArchiveAndARecoveryCopy() throws {
    var cart = sampleCart()
    cart.label = variedLabel()
    #expect(cart.label!.mainPaletteIndices.contains(0x3f))
    #expect(try Cart(files: cart.files) == cart)
    #expect(try Cart(fesArchive: cart.fesArchive) == cart)
    #expect(RecoveryCopy(text: RecoveryCopy.text(folder: nil, cart: cart)) == RecoveryCopy(folder: nil, edits: .wholeCart(cart)))
}

@Test func labelIsWrittenAfterTheMapAndBeforeOtherCodeFiles() {
    var cart = threeFileCart()
    cart.label = variedLabel()
    #expect(cart.fileNames.suffix(3) == ["label.hex", "enemy_2.lua", "player.lua"])
}

@Test func cartWithoutALabelHasNoLabelFileAndLoadsWithNoLabel() throws {
    let cart = sampleCart()
    #expect(cart.files["label.hex"] == nil)
    #expect(!cart.fileNames.contains("label.hex"))
    #expect(try Cart(files: cart.files).label == nil)
    #expect(try Cart(fesArchive: cart.fesArchive).label == nil)
}

@Test func labelFileIsReadInAnOlderFormatCart() throws {
    var cart = sampleCart()
    cart.label = variedLabel()
    var files = cart.files
    files["cart.json"] = files["cart.json"]!.replacing("\"format\" : 4", with: "\"format\" : 3")
    #expect(try Cart(files: files).label == cart.label)
}

@Test func malformedLabelIsRefusedNamingTheLineAndColumn() {
    #expect(
        labelRefusal(labelLines().dropLast().joined(separator: "\n") + "\n")
            == "label.hex line 144: expected 144 lines, found 143")
    #expect(
        labelRefusal(changingLine: 7, to: String(labelLines()[6].dropLast()))
            == "label.hex line 7: expected 384 hex digits, found 383")
    var line = Array(labelLines()[2])
    line.replaceSubrange(8...9, with: "40")
    #expect(
        labelRefusal(changingLine: 3, to: String(line))
            == "label.hex line 3: column 9: expected a main palette index 00–3f, found 40")
    line = Array(labelLines()[0])
    line.replaceSubrange(382...383, with: "0g")
    #expect(
        labelRefusal(changingLine: 1, to: String(line))
            == "label.hex line 1: column 383: expected a main palette index 00–3f, found 0g")
}

@Test func labelIsReadInUppercaseWithCRLFAndALeadingByteOrderMark() throws {
    var label = variedLabel()
    label.mainPaletteIndices[0] = 0x3f
    let text = "\u{FEFF}" + labelText(label).uppercased().replacing("\n", with: "\r\n")
    var files = sampleCart().files
    files["label.hex"] = text
    #expect(try Cart(files: files).label == label)
}

@Test func exactPaletteColorsCaptureAsTheirIndex() {
    for index in [0, 1, 37, 63] {
        #expect(capturedIndex(of: MainPalette()[index]) == UInt8(index))
    }
}

@Test func offPaletteColorCapturesAsTheNearestIndex() {
    #expect(capturedIndex(of: Color(rgb: 0x4d31bf)) == 1)
    var mainPalette = MainPalette()
    mainPalette[4] = Color(rgb: 0x101010)
    mainPalette[9] = Color(rgb: 0x101014)
    #expect(capturedIndex(of: Color(rgb: 0x101012), in: mainPalette) == 4)
}

@Test func duplicatePaletteColorCapturesAsTheLowerIndex() {
    var mainPalette = MainPalette()
    mainPalette[9] = mainPalette[3]
    #expect(capturedIndex(of: mainPalette[3], in: mainPalette) == 3)
}
