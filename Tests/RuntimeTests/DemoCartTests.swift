import Console
import GoldenImage
import Runtime
import Testing

@Test func demoFirstFrameMatchesGolden() throws {
    let cart = RunningCart(mainLua: DemoCart.mainLua, ppu: DemoCart.ppuWithTiles())
    var input = Input()
    input.beginFrame(held: 0)
    cart.runFrame(input: input)
    #expect(cart.error == nil)
    var frame = Framebuffer()
    cart.ppu.render(into: &frame)
    try expectFrameMatchesGolden(frame, named: "demo-start")
}

@Test func demoAfterHoldingDownRightFor60FramesMatchesGolden() throws {
    let cart = RunningCart(mainLua: DemoCart.mainLua, ppu: DemoCart.ppuWithTiles())
    let downRight = UInt8(1 << Button.down.rawValue | 1 << Button.right.rawValue)
    var input = Input()
    for _ in 0..<60 {
        input.beginFrame(held: downRight)
        cart.runFrame(input: input)
    }
    #expect(cart.error == nil)
    var frame = Framebuffer()
    cart.ppu.render(into: &frame)
    try expectFrameMatchesGolden(frame, named: "demo-after-60-frames-down-right")
}
