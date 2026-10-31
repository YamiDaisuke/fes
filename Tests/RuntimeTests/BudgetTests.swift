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
