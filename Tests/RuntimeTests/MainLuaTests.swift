import Runtime
import Testing

@Test func syntaxErrorNamesTheLineOfTheBadToken() {
    #expect(syntaxError(inMainLua: "x = 1\ny = = 2")?.hasPrefix("main.lua:2: unexpected symbol near '='") == true)
}

@Test func syntaxCheckReadsPastANulInAString() {
    #expect(syntaxError(inMainLua: "x = \"a\u{0}b\"\ny = = 2")?.hasPrefix("main.lua:2:") == true)
}

@Test func syntaxCheckDoesNotRunTheCode() {
    #expect(syntaxError(inMainLua: #"error("ran")"#) == nil)
}

@Test func syntaxErrorNearAHugeUnfinishedStringIsCut() {
    let error = syntaxError(inMainLua: "x = \"" + String(repeating: "a", count: 100_000) + "\n")
    #expect(error?.hasSuffix(" bytes shown]") == true)
    #expect(error!.utf8.count < 8192 + 64)
}

@Test func cutErrorEndsOnAWholeCharacter() {
    for padding in ["", "a"] {
        let error = syntaxError(inMainLua: "x = \"" + padding + String(repeating: "é", count: 10_000) + "\n")
        #expect(error?.contains("\u{FFFD}") == false)
    }
}

@Test func syntaxCheckKeepsTheMemoryCap() {
    #expect(syntaxError(inMainLua: "x = \"" + String(repeating: "a", count: 9 << 20) + "\"") == "memory budget exceeded")
}

@Test func runtimeErrorLineComesFromTheMessage() {
    let cart = RunningCart(mainLua: "\n\nerror('boom')")
    #expect(mainLuaLine(inError: cart.error!) == 3)
}

@Test func runtimeErrorLineFallsBackToTheTraceback() {
    let tableError = RunningCart(mainLua: "local x = 1\nerror({})")
    #expect(mainLuaLine(inError: tableError.error!) == 2)
    let errorWithoutPosition = RunningCart(mainLua: "\n\n\nerror('x', 0)")
    #expect(mainLuaLine(inError: errorWithoutPosition.error!) == 4)
}

@Test func errorInLoadedChunkPointsAtTheMainLuaCaller() {
    let cart = RunningCart(mainLua: "\n\n\nload(\"error('in chunk')\")()")
    #expect(mainLuaLine(inError: cart.error!) == 4)
}

@Test func budgetErrorsWithoutALineHaveNoLine() {
    let cart = RunningCart(mainLua: #"local s = string.rep("x", 1 << 30)"#)
    #expect(cart.error == "memory budget exceeded")
    #expect(mainLuaLine(inError: cart.error!) == nil)
}
