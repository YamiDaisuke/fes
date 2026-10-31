import Runtime
import Testing

private func firstErrorLine(_ cart: RunningCart) -> String? {
    cart.error?.split(separator: "\n").first.map(String.init)
}

@Test func runtimeErrorInUpdateReportsMainLuaAndTheLine() {
    let cart = RunningCart(mainLua: """
        function _update()
          local speed
          x = 1 + speed
        end
        """)
    cart.runFrame()
    #expect(firstErrorLine(cart) == "main.lua:3: attempt to perform arithmetic on a nil value (local 'speed')")
}

@Test func runsMainChunkAndInitOnceThenUpdateBeforeDrawEachFrame() {
    let cart = RunningCart(mainLua: """
        log = "main"
        draws = 0
        function _init() log = log .. " init" end
        function _update() log = log .. " update" end
        function _draw()
          log = log .. " draw"
          draws = draws + 1
          if draws == 2 then error(log, 0) end
        end
        """)
    cart.runFrame()
    cart.runFrame()
    #expect(firstErrorLine(cart) == "main init update draw update draw")
}

@Test func firstErrorStopsTheCart() {
    let cart = RunningCart(mainLua: """
        n = 0
        function _update()
          n = n + 1
          error("n=" .. n, 0)
        end
        """)
    cart.runFrame()
    cart.runFrame()
    #expect(firstErrorLine(cart) == "n=1")
}

@Test func missingCallbacksAreSkipped() {
    let cart = RunningCart(mainLua: "")
    cart.runFrame()
    cart.runFrame()
    #expect(cart.error == nil)
}

@Test func nonFunctionCallbackIsAnError() {
    let cart = RunningCart(mainLua: "_update = 5")
    cart.runFrame()
    #expect(cart.error?.contains("attempt to call a number value") == true)
}

@Test func strictGlobalsMetatableDoesNotBreakCallbackLookup() {
    let cart = RunningCart(mainLua: #"setmetatable(_G, {__index = function(_, k) error("undefined " .. k) end})"#)
    cart.runFrame()
    #expect(cart.error == nil)
}

@Test func syntaxErrorStopsBeforeRunning() {
    let cart = RunningCart(mainLua: "return 1 +")
    #expect(cart.error == "main.lua:1: unexpected symbol near <eof>")
}

@Test func bytecodeCartSourceIsRejected() {
    let cart = RunningCart(mainLua: "\u{1B}Lua")
    #expect(cart.error?.contains("attempt to load a binary chunk") == true)
}

@Test func nonStringErrorObjectIsNamedByType() {
    let cart = RunningCart(mainLua: "error({})")
    #expect(firstErrorLine(cart) == "(error object is a table value)")
}

@Test func erroringTostringOnErrorObjectDoesNotAbort() {
    let cart = RunningCart(mainLua: #"error(setmetatable({}, {__tostring = function() error("inner", 0) end}))"#)
    #expect(cart.error?.contains("inner") == true)
}

@Test func tostringThatRethrowsItselfEndsInStackOverflow() {
    let cart = RunningCart(mainLua: """
        local object = setmetatable({}, {})
        getmetatable(object).__tostring = function() error(object) end
        error(object)
        """)
    #expect(firstErrorLine(cart) == "C stack overflow")
}

@Test func sandboxHidesFilesOutputAndHostLibraries() {
    let cart = RunningCart(mainLua: """
        for _, name in ipairs({"io", "os", "package", "debug", "require", "dofile", "loadfile", "print", "warn", "loadstring"}) do
          if _G[name] ~= nil then error(name .. " is visible", 0) end
        end
        if string.dump ~= nil then error("string.dump is visible", 0) end
        """)
    #expect(cart.error == nil)
}

@Test func sandboxKeepsItsLibraries() {
    let cart = RunningCart(mainLua: """
        local kept = {string.format, table.insert, math.floor, utf8.char, coroutine.wrap, pcall, setmetatable, collectgarbage}
        for i = 1, 8 do
          if type(kept[i]) ~= "function" then error("kept function " .. i .. " is missing", 0) end
        end
        """)
    #expect(cart.error == nil)
}

@Test func loadRefusesBytecodeEvenWhenModeAsksForIt() {
    let cart = RunningCart(mainLua: #"""
        local chunk, message = load("\27Lua", "x", "b")
        error(tostring(chunk) .. " " .. message, 0)
        """#)
    #expect(firstErrorLine(cart) == "nil attempt to load a binary chunk (mode is 't')")
}

@Test func loadKeepsGlobalsByDefaultAndAcceptsAnEnvironment() {
    let cart = RunningCart(mainLua: """
        if load("return math.pi")() ~= math.pi then error("default environment lost", 0) end
        if load("return x", "c", "t", {x = 5})() ~= 5 then error("environment ignored", 0) end
        """)
    #expect(cart.error == nil)
}

@Test func loadArgumentErrorPointsAtTheCartLine() {
    let cart = RunningCart(mainLua: """
        function _update()
          local source
          load(source)
        end
        """)
    cart.runFrame()
    #expect(firstErrorLine(cart) == "main.lua:3: bad argument #1 to 'load' (function expected, got nil)")
}
