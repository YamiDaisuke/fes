import Console
import Storage
import Testing

private func sampleCart() -> Cart {
    var cart = Cart(name: "Ünï \"quoted\" cart 🎮", mainLua: "print(\"héllo\")\r\nx = 1\r\n")
    cart.backgroundTiles.setPixel(tile: 255, x: 7, y: 7, color: 7)
    cart.spriteTiles.setPixel(tile: 255, x: 7, y: 7, color: 3)
    cart.spritePalettes.setMasterIndex(63, palette: 7, index: 7)
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
    cart.spritePalettes.setMasterIndex(43, palette: 0, index: 1)
    let palettes = lines(cart.files["palettes.pal"])
    #expect(palettes[0] == "00 01 02 03 04 05 06 07")
    #expect(palettes[8] == "00 2b 02 03 04 05 06 07")
}

@Test func crlfAndUppercaseHexLoadTheSameAsLfAndLowercase() throws {
    let cart = sampleCart()
    var files = cart.files
    for name in ["cart.json", "background.tiles", "sprites.tiles", "palettes.pal", "map.map"] {
        files[name] = files[name]!.uppercased().replacing("\n", with: "\r\n")
    }
    files["cart.json"] = cart.files["cart.json"]!.replacing("\n", with: "\r\n")
    #expect(try Cart(files: files) == cart)
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
            == "palettes.pal line 3: entry 1: expected a master index 00–3f, found 40")

    var files = sampleCart().files
    files["sprites.tiles"] = lines(files["sprites.tiles"]).dropLast().joined(separator: "\n") + "\n"
    #expect(refusal(files) == "sprites.tiles line 128: expected 128 lines, found 127")
}

@Test func missingFileIsRefused() {
    var files = sampleCart().files
    files["map.map"] = nil
    #expect(refusal(files) == "map.map: file is missing")
}

@Test func badCartJSONIsRefused() {
    #expect(refusal(cartJSON: "{\"format\": 1, \"name\": ") == "cart.json: not valid JSON")
    #expect(
        refusal(cartJSON: "{\"format\": 2, \"name\": \"Room\"}")
            == "cart.json: This cart was made with a newer FES (format 2); this FES reads format 1.")
    #expect(
        refusal(cartJSON: "{\"format\": 2, \"title\": \"Room\"}")
            == "cart.json: This cart was made with a newer FES (format 2); this FES reads format 1.")
    #expect(refusal(cartJSON: "{\"format\": 1, \"name\": \" \\t \"}") == "cart.json: the name is empty")
}

