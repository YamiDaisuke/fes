import Console
import Storage
import Testing

private func sampleCart() -> Cart {
    var cart = Cart(name: "Ünï \"quoted\" cart 🎮", mainLua: "print(\"héllo\")\nx = 1\n")
    cart.backgroundTiles.setPixel(tile: 255, x: 7, y: 7, color: 7)
    cart.spriteTiles.setPixel(tile: 255, x: 7, y: 7, color: 3)
    cart.spritePalettes.setMainPaletteIndex(63, palette: 7, index: 7)
    cart.mainPalette[63] = Color(rgb: 0x0a0b0c)
    cart.mainPalette[0] = Color(rgb: 0xabcdef)
    cart.background[column: 31, row: 31] = Tilemap.Cell(tile: 255, palette: 7)
    return cart
}

private func lines(_ text: String?) -> [Substring] {
    text!.split(separator: "\n")
}

private func refusal(_ files: [String: String]) -> String? {
    do {
        _ = try Cart(files: files)
        return nil
    } catch {
        return error.description
    }
}

private func refusal(changing file: String, line: Int, to newLine: String) -> String? {
    var files = sampleCart().files
    var fileLines = lines(files[file]).map(String.init)
    fileLines[line - 1] = newLine
    files[file] = fileLines.joined(separator: "\n") + "\n"
    return refusal(files)
}

private func refusal(cartJSON: String) -> String? {
    var files = sampleCart().files
    files["cart.json"] = cartJSON
    return refusal(files)
}

@Test func cartSurvivesARoundTripThroughItsFiles() throws {
    let cart = sampleCart()
    #expect(try Cart(files: cart.files) == cart)
}

@Test func tilePixelSitsAtItsTileGridPositionInTheSheet() {
    var cart = sampleCart()
    cart.backgroundTiles.setPixel(tile: 18, x: 1, y: 0, color: 5)
    let sheet = lines(cart.files["background.tiles"])
    #expect(sheet.count == 128)
    #expect(Array(sheet[8])[17] == "5")
    #expect(Array(sheet[17])[8] == "0")
}

@Test func mapCellIsWrittenAsTileThenPaletteInItsRowAndColumn() {
    var cart = sampleCart()
    cart.background[column: 3, row: 1] = Tilemap.Cell(tile: 26, palette: 3)
    let map = lines(cart.files["map.map"])
    #expect(map[1].split(separator: " ")[3] == "1a3")
    #expect(map[0].split(separator: " ")[3] == "000")
}

@Test func paletteLineNineIsSpritePaletteZero() {
    var cart = sampleCart()
    cart.spritePalettes.setMainPaletteIndex(43, palette: 0, index: 1)
    let palettes = lines(cart.files["palettes.pal"])
    #expect(palettes[0] == "00 01 02 03 04 05 06 07")
    #expect(palettes[8] == "00 2b 02 03 04 05 06 07")
}

@Test func crlfAndUppercaseHexLoadTheSameAsLfAndLowercase() throws {
    let cart = sampleCart()
    var files = cart.files
    for name in ["background.tiles", "sprites.tiles", "main-palette.hex", "palettes.pal", "map.map"] {
        files[name] = files[name]!.uppercased().replacing("\n", with: "\r\n")
    }
    files["cart.json"] = cart.files["cart.json"]!.replacing("\n", with: "\r\n")
    #expect(try Cart(files: files) == cart)
}

@Test func mainLuaLineEndingsAreReadAsLFSoTheEditorTextMatchesTheLoadedCart() throws {
    var files = sampleCart().files
    files["main.lua"] = "a = 1\r\nb = 2\rc = 3\n\r\n\r\r"
    #expect(try Cart(files: files).mainLua == "a = 1\nb = 2\nc = 3\n\n\n\n")
}

@Test func malformedGridFilesAreRefusedNamingTheFileAndLine() {
    let digits = String(repeating: "0", count: 128)
    #expect(
        refusal(changing: "background.tiles", line: 5, to: "008" + digits.dropFirst(3))
            == "background.tiles line 5: column 3: expected a color 0–7, found 8")
    #expect(
        refusal(changing: "background.tiles", line: 2, to: String(digits.dropFirst()))
            == "background.tiles line 2: expected 128 digits, found 127")
    #expect(
        refusal(changing: "map.map", line: 4, to: "zz3" + String(repeating: " 000", count: 31))
            == "map.map line 4: cell 1: expected two hex digits of tile and a palette 0–7, found zz3")
    #expect(
        refusal(changing: "map.map", line: 4, to: "000" + String(repeating: " 000", count: 30))
            == "map.map line 4: expected 32 cells, found 31")
    #expect(
        refusal(changing: "palettes.pal", line: 3, to: "40 01 02 03 04 05 06 07")
            == "palettes.pal line 3: entry 1: expected a main palette index 00–3f, found 40")

    var files = sampleCart().files
    files["sprites.tiles"] = lines(files["sprites.tiles"]).dropLast().joined(separator: "\n") + "\n"
    #expect(refusal(files) == "sprites.tiles line 128: expected 128 lines, found 127")
}

@Test func sheetSeparatedByLoneCarriageReturnsIsRefused() {
    var files = sampleCart().files
    files["background.tiles"] = files["background.tiles"]!.replacing("\n", with: "\r")
    #expect(refusal(files) == "background.tiles line 2: expected 128 lines, found 1")
}

@Test func missingFileIsRefused() {
    var files = sampleCart().files
    files["map.map"] = nil
    #expect(refusal(files) == "map.map: file is missing")
}

@Test func badCartJSONIsRefused() {
    #expect(refusal(cartJSON: "{\"format\": 1, \"name\": ") == "cart.json: not valid JSON")
    #expect(
        refusal(cartJSON: "{\"format\": 3, \"name\": \"Room\"}")
            == "cart.json: This cart was made with a newer FES (format 3); this FES reads format 2.")
    #expect(
        refusal(cartJSON: "{\"format\": 3, \"title\": \"Room\"}")
            == "cart.json: This cart was made with a newer FES (format 3); this FES reads format 2.")
    #expect(refusal(cartJSON: "{\"format\": 1, \"name\": \" \\t \"}") == "cart.json: the name is empty")
    #expect(refusal(cartJSON: "{\"format\": 1, \"name\": \"\\u200b\\u200b\"}") == "cart.json: the name is empty")
}


@Test func nameLengthIsCountedInCharactersUpToSixtyFour() throws {
    let accentedE = "e\u{301}"
    var cart = sampleCart()
    cart.name = String(repeating: accentedE, count: 64)
    #expect(try Cart(files: cart.files).name == cart.name)
    cart.name += accentedE
    #expect(refusal(cart.files) == "cart.json: the name is longer than 64 characters")
}

@Test func nameWithALineBreakIsRefused() {
    #expect(
        refusal(cartJSON: "{\"format\": 1, \"name\": \"a\\nb\"}")
            == "cart.json: the name contains a line break or control character")
}

@Test func formatBelowOneIsRefused() {
    #expect(refusal(cartJSON: "{\"format\": 0, \"name\": \"Room\"}") == "cart.json: format 0 is not valid")
}

@Test func cartJSONIsReadInEitherKeyOrderWithAnyJSONWhitespace() throws {
    #expect(try parseCartJSON(" \r\n\t{\n\"name\"\t:\"Room\" ,\r\n \"format\":1 } \n") == (1, "Room"))
}

@Test func cartJSONNameEscapesAreDecoded() throws {
    let json = "{\"format\": 1, \"name\": \"\\u00e9\\u00C9\\ud83c\\udfae\\/\\\\\\\"\"}"
    #expect(try parseCartJSON(json).name == "éÉ🎮/\\\"")
}

@Test func cartJSONNameWithAControlCharacterIsWrittenEscaped() {
    let cart = Cart(name: "a\tb\u{1f}c", mainLua: "")
    #expect(cart.files["cart.json"] == "{\n  \"format\" : 2,\n  \"name\" : \"a\\tb\\u001fc\"\n}\n")
}

@Test func cartJSONNameEscapesQuotesBackslashesAndShortFormControlsButNotNonASCII() {
    let cart = Cart(name: "\u{8}\u{c}\"\\é🎮", mainLua: "")
    #expect(cart.files["cart.json"] == "{\n  \"format\" : 2,\n  \"name\" : \"\\b\\f\\\"\\\\é🎮\"\n}\n")
}

@Test func invalidStringsInCartJSONAreRefused() {
    for name in ["\\ud83c", "\\ud83cx", "\\udfae", "\\ud83c\\u0041", "\\x", "\\u12g4", "\\u+123", "a\tb"] {
        #expect(refusal(cartJSON: "{\"format\": 1, \"name\": \"\(name)\"}") == "cart.json: not valid JSON")
    }
}

@Test func duplicateKeysAndTrailingDataAreRefused() {
    #expect(
        refusal(cartJSON: "{\"format\": 1, \"name\": \"A\", \"name\": \"B\"}") == "cart.json: \"name\" appears twice")
    #expect(refusal(cartJSON: "{\"format\": 1, \"name\": \"A\"} x") == "cart.json: not valid JSON")
    #expect(refusal(cartJSON: "{\"format\": 1, \"name\": \"A\"}}") == "cart.json: not valid JSON")
    #expect(refusal(cartJSON: "{\"format\": 1, \"name\": \"A\",}") == "cart.json: not valid JSON")
    #expect(refusal(cartJSON: "[1]") == "cart.json: expected a JSON object")
}

@Test func formatThatIsNotAPlainIntegerIsRefused() {
    for format in ["1.0", "1e0", "\"1\"", "true", "99999999999999999999"] {
        #expect(
            refusal(cartJSON: "{\"format\": \(format), \"name\": \"Room\"}")
                == "cart.json: \"format\" must be an integer and \"name\" a string")
    }
    for format in ["01", "-", "1.", ".5", "1e", "+1"] {
        #expect(refusal(cartJSON: "{\"format\": \(format), \"name\": \"Room\"}") == "cart.json: not valid JSON")
    }
    #expect(refusal(cartJSON: "{\"format\": -1, \"name\": \"Room\"}") == "cart.json: format -1 is not valid")
}

@Test func unknownKeysWithNestedValuesAreIgnored() throws {
    let extra = "\"palette\": [[1, -2.5e-3], {\"a\": null, \"b\": false}, true, \"\\u0041\"]"
    #expect(try parseCartJSON("{\"format\": 1, \(extra), \"name\": \"Room\"}").name == "Room")
    #expect(
        refusal(cartJSON: "{\(extra), \"format\": 3}")
            == "cart.json: This cart was made with a newer FES (format 3); this FES reads format 2.")
}

@Test func deeplyNestedCartJSONIsRefusedWithoutCrashing() {
    let nested = String(repeating: "[", count: 100_000) + String(repeating: "]", count: 100_000)
    #expect(refusal(cartJSON: "{\"format\": 1, \"name\": \"Room\", \"x\": \(nested)}") == "cart.json: not valid JSON")
}

private func z64HexFromLospec() throws -> String {
    String(decoding: try fixture("z64.hex"), as: UTF8.self)
}

private func formatOneFiles(of cart: Cart) -> [String: String] {
    var files = cart.files
    files["cart.json"] = files["cart.json"]!.replacing("\"format\" : 2", with: "\"format\" : 1")
    files["main-palette.hex"] = nil
    return files
}

@Test func defaultMainPaletteIsWrittenAsLospecsZ64() throws {
    let lospec = try z64HexFromLospec()
    #expect(Cart(name: "Demo", mainLua: "").files["main-palette.hex"] == lospec.replacing("\r\n", with: "\n"))
}

@Test func lospecsZ64DownloadLoadsAsTheDefaultMainPalette() throws {
    var files = Cart(name: "Demo", mainLua: "").files
    files["main-palette.hex"] = try z64HexFromLospec().uppercased()
    #expect(try Cart(files: files).mainPalette == MainPalette())
}

@Test func malformedMainPaletteIsRefusedNamingTheFileAndLine() {
    for color in ["#4d30bf", "4d30b", "4d30bg", "4d30bf "] {
        #expect(
            refusal(changing: "main-palette.hex", line: 5, to: color)
                == "main-palette.hex line 5: expected a color rrggbb, found \(color)")
    }
    var files = sampleCart().files
    files["main-palette.hex"] = lines(files["main-palette.hex"]).dropLast().joined(separator: "\n") + "\n"
    #expect(refusal(files) == "main-palette.hex line 64: expected 64 lines, found 63")
}

@Test func formatTwoCartWithoutAMainPaletteIsRefused() {
    var files = sampleCart().files
    files["main-palette.hex"] = nil
    #expect(refusal(files) == "main-palette.hex: file is missing")
}

@Test func formatOneCartLoadsWithTheDefaultMainPaletteAndIsWrittenAsFormatTwo() throws {
    var cart = sampleCart()
    cart.mainPalette = MainPalette()
    let loaded = try Cart(files: formatOneFiles(of: cart))
    #expect(loaded == cart)
    #expect(loaded.files["cart.json"]!.contains("\"format\" : 2"))
}

@Test func formatOneCartIgnoresAMainPaletteFile() throws {
    var files = formatOneFiles(of: sampleCart())
    files["main-palette.hex"] = "not a palette"
    #expect(try Cart(files: files).mainPalette == MainPalette())
}
