import Console
import Runtime
import Testing

@Test func sprFillsTheSpriteTableInCallOrderWithItsAttributes() {
    let cart = RunningCart(mainLua: """
        spr(1, 10, 20, 2, true, false, true)
        spr(3, 30, 40)
        """)
    #expect(cart.ppu.sprites[0] == Sprite(x: 10, y: 20, tile: 1, palette: 2, isFlippedHorizontally: true, isBehindBackground: true))
    #expect(cart.ppu.sprites[1] == Sprite(x: 30, y: 40, tile: 3, palette: 0))
    #expect(cart.ppu.sprites[2] == nil)
}

@Test func spritesStayAcrossFramesUntilClsAndTheNextSprUsesEntryZero() {
    let cart = RunningCart(mainLua: """
        frame = 0
        function _draw()
          frame = frame + 1
          if frame == 1 then spr(1, 0, 0) spr(2, 0, 0) end
          if frame == 3 then cls() spr(5, 0, 0) end
        end
        """)
    cart.runFrame(input: Input())
    cart.runFrame(input: Input())
    #expect(cart.ppu.sprites[0]?.tile == 1)
    #expect(cart.ppu.sprites[1]?.tile == 2)
    cart.runFrame(input: Input())
    #expect(cart.ppu.sprites[0]?.tile == 5)
    #expect(cart.ppu.sprites[1] == nil)
}

@Test func the65thSprInATableIsDroppedAndEntryZeroIsKept() {
    let cart = RunningCart(mainLua: "for i = 1, 70 do spr(i, 0, 0) end")
    #expect(cart.ppu.sprites[0]?.tile == 1)
    #expect(cart.ppu.sprites[63]?.tile == 64)
}

@Test func fractionalArgumentsAreFlooredNotTruncated() {
    let cart = RunningCart(mainLua: """
        spr(0, 1.9, -0.5)
        mset(2.7, 0, 1)
        """)
    #expect(cart.ppu.sprites[0]?.x == 1)
    #expect(cart.ppu.sprites[0]?.y == -1)
    #expect(cart.ppu.background[column: 2, row: 0].tile == 1)
}

@Test func hugeArgumentsWrapToTheirFieldInsteadOfTrapping() {
    let cart = RunningCart(mainLua: """
        spr(257, 65541, -65535, 9)
        spr(0, 1e300, 0)
        mset(33, -1, 300, 9)
        local tile, palette = mget(1, 31)
        error(tile .. "," .. palette, 0)
        """)
    #expect(cart.ppu.sprites[0] == Sprite(x: 5, y: 1, tile: 1, palette: 1))
    #expect(firstErrorLine(cart) == "44,1")
}

@Test func nanAndInfinityRaiseAnErrorAtTheCartLine() {
    let cart = RunningCart(mainLua: """
        local messages = {}
        for _, value in ipairs({0/0, 1/0, -1/0}) do
          local _, message = pcall(function() spr(0, value, 0) end)
          messages[#messages + 1] = message
        end
        error(table.concat(messages, "|"), 0)
        """)
    let message = "main.lua:3: bad argument #2 to 'spr' (finite number expected)"
    #expect(firstErrorLine(cart) == [message, message, message].joined(separator: "|"))
}

@Test func nonNumberAndMissingArgumentsRaiseLuaArgumentErrors() {
    let cart = RunningCart(mainLua: """
        local function failure(call) local _, message = pcall(call) return message end
        spr("5", 0, 0)
        error(table.concat({
          failure(function() spr("a", 0, 0) end),
          failure(function() spr(0, 0) end),
          failure(function() btn() end),
        }, "|"), 0)
        """)
    #expect(cart.ppu.sprites[0]?.tile == 5)
    #expect(firstErrorLine(cart) == [
        "main.lua:4: bad argument #1 to 'spr' (number expected, got string)",
        "main.lua:5: bad argument #3 to 'spr' (number expected, got no value)",
        "main.lua:6: bad argument #1 to 'btn' (number expected, got no value)",
    ].joined(separator: "|"))
}

@Test func flipAndPriorityAcceptOnlyBooleansOrNil() {
    let cart = RunningCart(mainLua: """
        spr(0, 0, 0, 0, nil, nil, nil)
        spr(0, 0, 0, 0, 1)
        """)
    #expect(cart.ppu.sprites[0] == Sprite(x: 0, y: 0, tile: 0, palette: 0))
    #expect(firstErrorLine(cart) == "main.lua:2: bad argument #5 to 'spr' (boolean expected, got number)")
}

@Test func bindingErrorsAreCatchableByPcallAndTheCartKeepsRunning() {
    let cart = RunningCart(mainLua: """
        if pcall(spr) then error("spr() did not raise", 0) end
        spr(3, 0, 0)
        """)
    #expect(cart.ppu.sprites[0]?.tile == 3)
    #expect(cart.error == nil)
}

@Test func aCartWhoseBindingRaisedIsStillDeallocated() {
    weak var weakCart: RunningCart?
    do {
        let cart = RunningCart(mainLua: "pcall(spr) pcall(mset, 0, 0) pcall(mget) pcall(btn) pcall(btnp) pcall(camera, 0/0)")
        weakCart = cart
    }
    #expect(weakCart == nil)
}

@Test func btnAndBtnpThroughLuaFollowHeldAndFirstFrame() {
    let cart = RunningCart(mainLua: """
        frame, log = 0, ""
        function _update()
          frame = frame + 1
          log = log .. tostring(btn(1)) .. "/" .. tostring(btnp(1)) .. " "
          if frame == 3 then error(log, 0) end
        end
        """)
    var input = Input()
    for held in [1 << Button.right.rawValue, 1 << Button.right.rawValue, 0] {
        input.beginFrame(held: UInt8(held))
        cart.runFrame(input: input)
    }
    #expect(firstErrorLine(cart) == "true/true true/false false/false ")
}

@Test func btnNumbersFollowButtonOrderAndOutOfRangeIsFalse() {
    let cart = RunningCart(mainLua: """
        function _update()
          error(table.concat({tostring(btn(4)), tostring(btn(5)), tostring(btn(8)), tostring(btn(-1)), tostring(btn(2^40)), tostring(btn(4.5))}, " "), 0)
        end
        """)
    var input = Input()
    input.beginFrame(held: 1 << Button.a.rawValue | 1 << Button.left.rawValue | 1 << Button.select.rawValue)
    cart.runFrame(input: input)
    #expect(firstErrorLine(cart) == "true false false false false true")
}

@Test func cameraScrollsTheBackgroundAndOffsetsOnlyLaterSprites() {
    let cart = RunningCart(mainLua: """
        spr(0, 10, 10)
        camera(3, -2)
        spr(0, 10, 10)
        function _draw() camera() end
        """)
    #expect(cart.ppu.sprites[0] == Sprite(x: 10, y: 10, tile: 0, palette: 0))
    #expect(cart.ppu.sprites[1] == Sprite(x: 7, y: 12, tile: 0, palette: 0))
    #expect(cart.ppu.scrollX == 3)
    #expect(cart.ppu.scrollY == -2)
    cart.runFrame(input: Input())
    #expect(cart.ppu.scrollX == 0)
    #expect(cart.ppu.scrollY == 0)
}

@Test func msetThenMgetRoundTripsWithPaletteDefaultingToZero() {
    let cart = RunningCart(mainLua: """
        mset(5, 6, 7, 3)
        mset(8, 9, 10, 5)
        mset(8, 9, 10)
        local tile1, palette1 = mget(5, 6)
        local tile2, palette2 = mget(8, 9)
        error(tile1 .. "," .. palette1 .. " " .. tile2 .. "," .. palette2, 0)
        """)
    #expect(firstErrorLine(cart) == "7,3 10,0")
}
