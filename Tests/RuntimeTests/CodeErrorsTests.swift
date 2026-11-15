import Runtime
import Testing

@Test func syntaxErrorNamesTheLineOfTheBadToken() {
    #expect(syntaxError(inLua: "x = 1\ny = = 2", named: "main.lua")?.hasPrefix("main.lua:2: unexpected symbol near '='") == true)
}

@Test func syntaxCheckReadsPastANulInAString() {
    #expect(syntaxError(inLua: "x = \"a\u{0}b\"\ny = = 2", named: "main.lua")?.hasPrefix("main.lua:2:") == true)
}

@Test func syntaxCheckDoesNotRunTheCode() {
    #expect(syntaxError(inLua: #"error("ran")"#, named: "main.lua") == nil)
}

@Test func syntaxErrorNearAHugeUnfinishedStringIsCut() {
    let error = syntaxError(inLua: "x = \"" + String(repeating: "a", count: 100_000) + "\n", named: "main.lua")
    #expect(error?.hasSuffix(" bytes shown]") == true)
    #expect(error!.utf8.count < 8192 + 64)
}

@Test func cutErrorEndsOnAWholeCharacter() {
    for padding in ["", "a"] {
        let error = syntaxError(inLua: "x = \"" + padding + String(repeating: "é", count: 10_000) + "\n", named: "main.lua")
        #expect(error?.contains("\u{FFFD}") == false)
    }
}

@Test func syntaxCheckKeepsTheMemoryCap() {
    #expect(syntaxError(inLua: "x = \"" + String(repeating: "a", count: 9 << 20) + "\"", named: "main.lua") == "memory budget exceeded")
}

@Test func runtimeErrorLineComesFromTheMessage() {
    let cart = RunningCart(mainLua: "\n\nerror('boom')")
    #expect(codePosition(inError: cart.error!, files: ["main.lua"])?.line == 3)
}

@Test func runtimeErrorLineFallsBackToTheTraceback() {
    let tableError = RunningCart(mainLua: "local x = 1\nerror({})")
    #expect(codePosition(inError: tableError.error!, files: ["main.lua"])?.line == 2)
    let errorWithoutPosition = RunningCart(mainLua: "\n\n\nerror('x', 0)")
    #expect(codePosition(inError: errorWithoutPosition.error!, files: ["main.lua"])?.line == 4)
}

@Test func errorInLoadedChunkPointsAtTheMainLuaCaller() {
    let cart = RunningCart(mainLua: "\n\n\nload(\"error('in chunk')\")()")
    #expect(codePosition(inError: cart.error!, files: ["main.lua"])?.line == 4)
}

@Test func budgetErrorsWithoutALineHaveNoLine() {
    let cart = RunningCart(mainLua: #"local s = string.rep("x", 1 << 30)"#)
    #expect(cart.error == "memory budget exceeded")
    #expect(codePosition(inError: cart.error!, files: ["main.lua"]) == nil)
}
