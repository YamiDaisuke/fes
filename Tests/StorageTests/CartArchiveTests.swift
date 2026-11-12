import Console
import Foundation
@testable import Storage
import Testing

private func refusal(_ archive: [UInt8]) -> String? {
    do {
        _ = try Cart(fesArchive: archive)
        return nil
    } catch {
        return "\(error)"
    }
}

private func archive(of cart: Cart, changing changes: [String: [UInt8]?] = [:]) -> [UInt8] {
    var entries = cart.files.mapValues { Array($0.utf8) }
    for (name, bytes) in changes {
        entries[name] = bytes
    }
    return storedZip(entries.sorted { $0.key < $1.key }.map { (name: $0.key, bytes: $0.value) })
}

@Test func cartSurvivesAFesArchiveRoundTrip() throws {
    var cart = Cart(name: "Ünï cart 🎮", mainLua: "print(\"a\\0b\")\n-- \u{0}\n")
    cart.backgroundTiles.setPixel(tile: 255, x: 7, y: 7, color: 7)
    cart.spriteTiles.setPixel(tile: 1, x: 0, y: 3, color: 2)
    cart.backgroundPalettes.setMainPaletteIndex(12, palette: 3, index: 1)
    cart.spritePalettes.setMainPaletteIndex(63, palette: 7, index: 7)
    cart.background[column: 31, row: 31] = Tilemap.Cell(tile: 255, palette: 7)

    #expect(try Cart(fesArchive: cart.fesArchive) == cart)
}

@Test func formatOneArchiveMadeByInfoZipLoadsWithTheDefaultMainPalette() throws {
    // Made with: zip -0 -X -D made-by-zip.fes * in a folder holding T15b's format 1 Cart(name: "Fixture", mainLua: "print(1)").files.
    let cart = try Cart(fesArchive: fixture("made-by-zip.fes"))
    #expect(cart == Cart(name: "Fixture", mainLua: "print(1)"))
    #expect(cart.mainPalette == MainPalette())
}

@Test func formatOneArchiveMadeByInfoZipWithExtraFieldsAndACommentLoadsWithTheDefaultMainPalette() throws {
    // Made with: echo "A cart for FES" | zip -0 -D -z made-by-zip-with-extras-and-a-comment.fes * in the same format 1 folder.
    let cart = try Cart(fesArchive: fixture("made-by-zip-with-extras-and-a-comment.fes"))
    #expect(cart == Cart(name: "Fixture", mainLua: "print(1)"))
    #expect(cart.mainPalette == MainPalette())
}

@Test func unknownEntriesAreIgnored() throws {
    let cart = Cart(name: "Demo", mainLua: "print(1)")
    let withExtras = archive(of: cart, changing: ["__MACOSX/._main.lua": [0, 0xFF], "notes.txt": Array("hi".utf8)])

    #expect(try Cart(fesArchive: withExtras) == cart)
}

@Test func entryNamedLikeACartFileInAnotherCaseAsAFolderOrWithALeadingPathIsRefused() {
    let cart = Cart(name: "Demo", mainLua: "print(1)")

    #expect(refusal(archive(of: cart, changing: ["MAIN.LUA": Array("print(2)".utf8)])) == "MAIN.LUA could be unzipped as main.lua")
    #expect(refusal(archive(of: cart, changing: ["main.lua/": []])) == "main.lua/ could be unzipped as main.lua")
    #expect(refusal(archive(of: cart, changing: ["./main.lua": Array("print(2)".utf8)])) == "./main.lua could be unzipped as main.lua")
    #expect(refusal(archive(of: cart, changing: ["/Map.map": []])) == "/Map.map could be unzipped as map.map")
}

@Test func archiveWithoutMainLuaNamesTheMissingFile() {
    #expect(refusal(archive(of: Cart(name: "Demo", mainLua: ""), changing: ["main.lua": nil])) == "main.lua: file is missing")
}

@Test func cartFileThatIsNotUTF8IsRefused() {
    var map = Array(Cart(name: "Demo", mainLua: "").files["map.map"]!.utf8)
    map[0] = 0xFF

    #expect(refusal(archive(of: Cart(name: "Demo", mainLua: ""), changing: ["map.map": map])) == "map.map: not valid UTF-8")
}

@Test func fileLargerThan8MiBIsRefusedBeforeItIsRead() {
    #expect(refusal([UInt8](repeating: 0, count: Cart.largestArchiveBytes + 1)) == "larger than 8 MiB")
}

@Test func fesFileNameReplacesCharactersFilesRejectsAndAvoidsHiddenFiles() {
    #expect(fesFileName(forCartName: "a/b:c") == "a-b-c.fes")
    #expect(fesFileName(forCartName: " .hidden ") == "-hidden.fes")
    #expect(fesFileName(forCartName: "Demo") == "Demo.fes")
}

@Test func fesFileNameKeepsWholeCharactersWithin200Bytes() {
    let family = "👨‍👩‍👧‍👦"
    #expect(fesFileName(forCartName: String(repeating: family, count: 64)) == String(repeating: family, count: 8) + ".fes")
}

@Test func fesFileNameIsNeverHiddenWhenTheCutLeavesOnlySpacesOrNothing() {
    #expect(fesFileName(forCartName: String(repeating: "\u{3000}", count: 63) + "👨‍👩‍👧‍👦") == "👨‍👩‍👧‍👦.fes")
    #expect(fesFileName(forCartName: "e" + String(repeating: "\u{301}", count: 100)) == "cart.fes")
}

@Test func fesFileNameReplacesRejectedCharactersAndLeadingDotsEvenWhenAMarkFollowsThem() {
    #expect(fesFileName(forCartName: ".\u{301}abc") == "-\u{301}abc.fes")
    #expect(fesFileName(forCartName: "a/\u{301}b:\u{200D}c|\u{FE0F}") == "a-\u{301}b-\u{200D}c-\u{FE0F}.fes")
}
