import Console
import Runtime
import Testing

@Test func infiniteLoopInUpdateStopsWithCPUBudgetOnItsLine() {
    let cart = RunningCart(mainLua: """
        function _update()
          while true do end
        end
        """)
    cart.runFrame(input: Input())
    #expect(firstErrorLine(cart) == "main.lua:2: CPU budget exceeded")
}

@Test func infiniteLoopInInitStopsTheCart() {
    let cart = RunningCart(mainLua: """
        function _init() while true do end end
        function _update() error("update ran", 0) end
        """)
    cart.runFrame(input: Input())
    #expect(firstErrorLine(cart) == "main.lua:1: CPU budget exceeded")
}

@Test func pcallCannotSwallowTheCPUBudget() {
    let cart = RunningCart(mainLua: """
        function _update()
          while true do pcall(function() while true do end end) end
        end
        """)
    cart.runFrame(input: Input())
    #expect(firstErrorLine(cart)?.hasSuffix("CPU budget exceeded") == true)
}

@Test(arguments: [
    "function _update() return pcall(spin) end",
    "return pcall(spin)",
])
func budgetErrorCaughtByATailCalledPcallStillStopsTheCart(tail: String) {
    let cart = RunningCart(mainLua: "local function spin() while true do end end\n" + tail)
    cart.runFrame(input: Input())
    #expect(cart.error == "CPU budget exceeded")
}

@Test func oneCoroutineResumePerFrameCannotSwallowTheBudget() {
    let cart = RunningCart(mainLua: """
        function _update() coroutine.resume(coroutine.create(function() while true do end end)) end
        """)
    cart.runFrame(input: Input())
    #expect(cart.error == "CPU budget exceeded")
}

@Test func heavyLibraryCallsInALoopStopAtTheDeadline() {
    let cart = RunningCart(mainLua: """
        function _update() for i = 1, 2000 do local s = string.rep("x", 1000000) end end
        """)
    cart.runFrame(input: Input())
    #expect(firstErrorLine(cart) == "main.lua:1: CPU budget exceeded")
}

@Test func newCoroutinesDoNotGetAFreshBudget() {
    let cart = RunningCart(mainLua: """
        local function loop() while true do end end
        function _update()
          while true do coroutine.resume(coroutine.create(loop)) end
        end
        """)
    cart.runFrame(input: Input())
    #expect(firstErrorLine(cart)?.hasSuffix("CPU budget exceeded") == true)
}

@Test func budgetResetsEveryFrameIncludingInsideACoroutine() {
    let cart = RunningCart(mainLua: """
        local step = coroutine.wrap(function()
          while true do
            for i = 1, \(Budgets.instructionsPerFrame * 6 / 10) do end
            coroutine.yield()
          end
        end)
        function _update() step() end
        """)
    for _ in 1...10 {
        cart.runFrame(input: Input())
    }
    #expect(cart.error == nil)
}

@Test func allocationBombStopsWithMemoryBudget() {
    let cart = RunningCart(mainLua: """
        local t = {}
        function _update()
          for i = 1, 50000 do t[#t + 1] = {} end
        end
        """)
    for _ in 1...10 {
        cart.runFrame(input: Input())
    }
    #expect(cart.error == "memory budget exceeded")
}

@Test func twoGigabyteStringRepIsRefused() {
    let cart = RunningCart(mainLua: #"s = string.rep("x", 2e9)"#)
    #expect(cart.error == "memory budget exceeded")
}

@Test func callCycleStopsWithStackOverflow() {
    let cart = RunningCart(mainLua: "local t = {} setmetatable(t, {__call = t}) t()")
    #expect(firstErrorLine(cart) == "main.lua:1: stack overflow")
}

@Test func caughtMemoryErrorLetsTheCartContinue() {
    let cart = RunningCart(mainLua: """
        local ok, m = pcall(string.rep, "x", 2e9)
        if ok or m ~= "not enough memory" then error("wrong", 0) end
        """)
    cart.runFrame(input: Input())
    #expect(cart.error == nil)
}

@Test func setmetatableRefusesAFinalizerAtTheCartsLine() {
    let cart = RunningCart(mainLua: """
        local mt = {}
        rawset(mt, "__gc", function() while true do end end)
        setmetatable({}, mt)
        """)
    #expect(firstErrorLine(cart) == "main.lua:3: __gc metamethods are not allowed")
}

@Test func setmetatableRefusesAPlaceholderFinalizerThatCouldBeSwappedLater() {
    let cart = RunningCart(mainLua: "setmetatable({}, {__gc = false})")
    #expect(firstErrorLine(cart) == "main.lua:1: __gc metamethods are not allowed")
}

@Test func finalizerAddedAfterSetmetatableNeverRuns() {
    let cart = RunningCart(mainLua: """
        local function loop() while true do end end
        local mt = {}
        local t = setmetatable({}, mt)
        mt.__gc = loop
        getmetatable("").__gc = loop
        t = nil
        collectgarbage()
        """)
    #expect(cart.error == nil)
}

@Test(arguments: [
    "xpcall(function() while true do end end, function(m) while true do end end)",
    "xpcall(error, function(m) while true do end end)",
])
func xpcallHandlerCannotRunOnceTheBudgetIsSpent(update: String) {
    let cart = RunningCart(mainLua: "function _update() \(update) end")
    cart.runFrame(input: Input())
    #expect(cart.error == "CPU budget exceeded")
}

@Test func xpcallUnderBudgetCallsTheHandlerPassesArgumentsAndYields() {
    let cart = RunningCart(mainLua: """
        local ok, m = xpcall(error, function(m) return m .. "!" end, "boom", 0)
        if ok or m ~= "boom!" then error("handler not called", 0) end
        local ok, a, b = xpcall(function(x, y) return y, x end, tostring, 1, 2)
        if not ok or a ~= 2 or b ~= 1 then error("results lost", 0) end
        local step = coroutine.wrap(function() xpcall(coroutine.yield, tostring, "yielded") end)
        if step() ~= "yielded" then error("yield lost", 0) end
        """)
    #expect(cart.error == nil)
}
