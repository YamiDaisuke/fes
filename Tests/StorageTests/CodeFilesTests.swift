import Storage
import Testing

private let thirtyTwoLetters = String(repeating: "a", count: 32)

@Test(arguments: ["player.lua", "_x.lua", "a1_b.lua", "main.lua", thirtyTwoLetters + ".lua"])
func goodCodeFileNamesHaveNoProblem(name: String) {
    #expect(codeFileNameProblem(name) == nil)
}

@Test(arguments: [
    ("player", "code file names end in .lua"),
    ("player.LUA", "code file names end in .lua"),
    (".lua", "the name before .lua is empty"),
    ("Player.lua", "code file names use a–z, 0–9 and _, such as player.lua"),
    ("my player.lua", "code file names use a–z, 0–9 and _, such as player.lua"),
    ("src/player.lua", "code file names use a–z, 0–9 and _, such as player.lua"),
    ("é.lua", "code file names use a–z, 0–9 and _, such as player.lua"),
    ("1up.lua", "code file names can't start with a digit"),
    (thirtyTwoLetters + "a.lua", "the name before .lua is longer than 32 characters"),
])
func badCodeFileNamesSayWhatToFix(name: String, problem: String) {
    #expect(codeFileNameProblem(name) == problem)
}

private func refusal(_ files: [String: String]) -> String? {
    do {
        _ = try Cart(files: files)
        return nil
    } catch {
        return error.description
    }
}

private func names(_ cart: Cart) -> [String] {
    cart.codeFiles.map(\.name)
}

@Test func threeFileCartSurvivesARoundTripThroughFilesAFesArchiveAndARecoveryCopy() throws {
    let cart = threeFileCart()
    #expect(cart.fileNames.suffix(2) == ["enemy_2.lua", "player.lua"])
    #expect(try Cart(files: cart.files) == cart)
    #expect(try Cart(fesArchive: cart.fesArchive) == cart)
    #expect(RecoveryCopy(text: RecoveryCopy.text(folder: nil, cart: cart)) == RecoveryCopy(folder: nil, edits: .wholeCart(cart)))
}

@Test func codeFileLineEndingsAndByteOrderMarkAreReadLikeMainLua() throws {
    var files = sampleCart().files
    files["player.lua"] = "\u{FEFF}a = 1\r\nb = 2\rc = 3\n"
    #expect(try Cart(files: files).codeFiles[1].text == "a = 1\nb = 2\nc = 3\n")
}

@Test func formatTwoCartLoadsTheSameAndIsWrittenAsFormatThree() throws {
    let cart = sampleCart()
    var files = cart.files
    files["cart.json"] = files["cart.json"]!.replacing("\"format\" : 3", with: "\"format\" : 2")
    let loaded = try Cart(files: files)
    #expect(loaded == cart)
    #expect(loaded.files["cart.json"]!.contains("\"format\" : 3"))
}

@Test func fileEndingInLuaWithABadNameIsRefusedNotIgnored() {
    var files = sampleCart().files
    files["Player.lua"] = "return 1\n"
    #expect(refusal(files) == "Player.lua: code file names use a–z, 0–9 and _, such as player.lua")
}

@Test func thirtyThirdCodeFileIsRefusedByName() {
    var files = sampleCart().files
    for number in 1...32 {
        files["f\(number).lua"] = ""
    }
    #expect(refusal(files) == "f9.lua: a cart holds at most 32 code files")
}

@Test func addedCodeFilesAreKeptSortedAfterMainLua() {
    var cart = sampleCart()
    for name in ["zed.lua", "alpha.lua", "_a.lua"] {
        #expect(cart.addCodeFile(named: name) == nil)
    }
    #expect(names(cart) == ["main.lua", "_a.lua", "alpha.lua", "zed.lua"])
    #expect(cart.renameCodeFile("alpha.lua", to: "zz.lua") == nil)
    #expect(names(cart) == ["main.lua", "_a.lua", "zed.lua", "zz.lua"])
}

@Test func renamedCodeFileKeepsItsText() {
    var cart = threeFileCart()
    #expect(cart.renameCodeFile("enemy_2.lua", to: "zz.lua") == nil)
    #expect(cart.codeFiles.last?.name == "zz.lua")
    #expect(cart.codeFiles.last?.text == threeFileCart().codeFiles[1].text)
}

@Test func addingADuplicateABadNameOrAThirtyThirdFileIsRefusedAndChangesNothing() {
    var cart = threeFileCart()
    let before = cart
    #expect(cart.addCodeFile(named: "player.lua") == "this cart already has it")
    #expect(cart.addCodeFile(named: "main.lua") == "this cart already has it")
    #expect(cart.addCodeFile(named: "Enemy.lua") == "code file names use a–z, 0–9 and _, such as player.lua")
    #expect(cart == before)

    for number in 4...32 {
        #expect(cart.addCodeFile(named: "f\(number).lua") == nil)
    }
    let full = cart
    #expect(cart.addCodeFile(named: "one_more.lua") == "a cart holds at most 32 code files")
    #expect(cart == full)
}

@Test func renamingOntoAnotherFileMainLuaOrAMissingFileIsRefusedAndChangesNothing() {
    var cart = threeFileCart()
    let before = cart
    #expect(cart.renameCodeFile("player.lua", to: "enemy_2.lua") == "this cart already has it")
    #expect(cart.renameCodeFile("player.lua", to: "main.lua") == "this cart already has it")
    #expect(cart.renameCodeFile("main.lua", to: "start.lua") == "the cart starts from main.lua")
    #expect(cart.renameCodeFile("ghost.lua", to: "spirit.lua") == "this cart has no such file")
    #expect(cart.renameCodeFile("player.lua", to: "Player.lua") == "code file names use a–z, 0–9 and _, such as player.lua")
    #expect(cart == before)
}

@Test func renamingAFileToItsOwnNameIsNotAProblem() {
    var cart = threeFileCart()
    #expect(cart.renameCodeFile("player.lua", to: "player.lua") == nil)
    #expect(cart == threeFileCart())
}

@Test func removingMainLuaOrAMissingFileIsRefusedAndChangesNothing() {
    var cart = threeFileCart()
    #expect(cart.removeCodeFile(named: "main.lua") == "the cart starts from main.lua")
    #expect(cart.removeCodeFile(named: "ghost.lua") == "this cart has no such file")
    #expect(cart == threeFileCart())
    #expect(cart.removeCodeFile(named: "player.lua") == nil)
    #expect(names(cart) == ["main.lua", "enemy_2.lua"])
}
