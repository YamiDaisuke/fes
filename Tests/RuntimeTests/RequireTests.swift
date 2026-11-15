import Console
import Runtime
import Testing

@Test func requireReturnsWhatTheModuleReturns() {
    let cart = RunningCart(mainLua: """
        local player = require("player")
        error("speed " .. player.speed, 0)
        """, modules: ["player.lua": "return {speed = 3}"])
    #expect(firstErrorLine(cart) == "speed 3")
}

@Test func secondRequireReturnsTheSameValueWithoutRunningTheFileAgain() {
    let cart = RunningCart(mainLua: """
        runs = 0
        local a = require("player")
        local b = require("player")
        error(runs .. " " .. tostring(a == b), 0)
        """, modules: ["player.lua": "runs = runs + 1\nreturn {}"])
    #expect(firstErrorLine(cart) == "1 true")
}

@Test func moduleReturningNothingGivesTrueAndReturningFalseIsKept() {
    let cart = RunningCart(mainLua: """
        runs = 0
        local nothing = require("nothing")
        local first, second = require("no"), require("no")
        error(tostring(nothing) .. " " .. tostring(first) .. " " .. tostring(second) .. " " .. runs, 0)
        """, modules: ["nothing.lua": "", "no.lua": "runs = runs + 1\nreturn false"])
    #expect(firstErrorLine(cart) == "true false false 1")
}

@Test func moduleReceivesItsName() {
    let cart = RunningCart(mainLua: #"error(require("player"), 0)"#, modules: ["player.lua": "return ..."])
    #expect(firstErrorLine(cart) == "player")
}

@Test func missingModuleNamesTheRequireLineAndTheFile() {
    let cart = RunningCart(mainLua: "\n\nlocal p = require(\"plyer\")", modules: ["player.lua": "return {}"])
    #expect(firstErrorLine(cart) == "main.lua:3: module 'plyer' not found: this cart has no file plyer.lua")
}

@Test func nameWithANulIsNotCutShort() {
    let cart = RunningCart(mainLua: #"require("player\0x")"#, modules: ["player.lua": "return {}"])
    #expect(firstErrorLine(cart)?.hasPrefix("main.lua:1: module 'player") == true)
    #expect(firstErrorLine(cart)?.hasSuffix("' not found: this cart has no file player\u{0}x.lua") == true)
}

@Test func mainCannotBeRequired() {
    let cart = RunningCart(mainLua: #"require("main")"#)
    #expect(firstErrorLine(cart) == "main.lua:1: module 'main' can't be required: the cart starts from main.lua")
}

@Test func moduleRequiringItselfStopsAtTheRequireCall() {
    let cart = RunningCart(mainLua: #"require("a")"#, modules: ["a.lua": #"require("a")"#])
    #expect(firstErrorLine(cart) == "a.lua:1: module 'a' is still loading (circular require)")
}

@Test func cycleThroughASecondFileStopsWhereItCloses() {
    let cart = RunningCart(mainLua: #"require("a")"#, modules: ["a.lua": #"require("b")"#, "b.lua": #"require("a")"#])
    #expect(firstErrorLine(cart) == "b.lua:1: module 'a' is still loading (circular require)")
}

@Test func runtimeErrorInAModuleFunctionNamesTheModuleAndItsLine() {
    let cart = RunningCart(mainLua: """
        local player = require("player")
        function _update() player.move() end
        """, modules: ["player.lua": """
        local player = {}
        function player.move()
          local speed
          return speed + 1
        end
        return player
        """])
    cart.runFrame(input: Input())
    #expect(firstErrorLine(cart) == "player.lua:4: attempt to perform arithmetic on a nil value (local 'speed')")
    let position = codePosition(inError: cart.error!, files: ["main.lua", "player.lua"])
    #expect(position?.file == "player.lua")
    #expect(position?.line == 4)
}

@Test func syntaxErrorInAModuleNamesTheModule() {
    let cart = RunningCart(mainLua: #"require("player")"#, modules: ["player.lua": "\n\n\nx = = 1"])
    #expect(firstErrorLine(cart) == "player.lua:4: unexpected symbol near '='")
}

@Test func nonStringNameIsABadArgumentOnTheCallerLine() {
    let cart = RunningCart(mainLua: "\nrequire({})")
    #expect(firstErrorLine(cart) == "main.lua:2: bad argument #1 to 'require' (string expected, got table)")
}

@Test func endlessLoopInAModuleStopsOnTheModuleLine() {
    let cart = RunningCart(mainLua: #"require("player")"#, modules: ["player.lua": "x = 1\nwhile true do end"])
    #expect(firstErrorLine(cart) == "player.lua:2: CPU budget exceeded")
}

@Test func moduleTooBigToLoadUnderTheCapStopsWithTheMemoryBudget() {
    let hugeString = "x = \"" + String(repeating: "a", count: 9 << 20) + "\""
    let cart = RunningCart(mainLua: #"require("player")"#, modules: ["player.lua": hugeString])
    #expect(cart.error == "memory budget exceeded")
}

@Test func moduleAllocatingPastTheCapWhileItRunsStopsWithTheMemoryBudget() {
    let cart = RunningCart(mainLua: #"require("player")"#, modules: ["player.lua": #"local s = string.rep("x", 16 << 20)"#])
    #expect(cart.error == "memory budget exceeded")
}

@Test func tableErrorInAModuleIsPlacedFromTheTraceback() {
    let cart = RunningCart(mainLua: "\n\nrequire(\"player\")", modules: ["player.lua": "\nerror({})"])
    let position = codePosition(inError: cart.error!, files: ["main.lua", "player.lua"])
    #expect(position?.file == "player.lua")
    #expect(position?.line == 2)
}
