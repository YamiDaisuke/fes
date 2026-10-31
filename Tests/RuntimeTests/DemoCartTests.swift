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
    try expectDemoMatchesGolden(afterHoldingDownRightFor: 60, named: "demo-after-60-frames-down-right")
}

@Test func demoHoldingDownRightIntoTheCornerStopsAtBothWallsMatchesGolden() throws {
    try expectDemoMatchesGolden(afterHoldingDownRightFor: 200, named: "demo-after-200-frames-down-right")
}

@Test func demoPlayerHalfUnderAPillarStopsWhenOnlyItsTopRightCornerMeetsIt() {
    let cart = RunningCart(mainLua: DemoCart.mainLua, ppu: DemoCart.ppuWithTiles())
    var input = Input()
    hold([.left], for: 4, in: cart, input: &input)
    hold([.up], for: 30, in: cart, input: &input)
    #expect(cart.error == nil)
    let player = cart.ppu.sprites[0]!
    #expect(player.x + cart.ppu.scrollX == 84)
    #expect(player.y + cart.ppu.scrollY == 48)
}

private func expectDemoMatchesGolden(afterHoldingDownRightFor frames: Int, named name: String) throws {
    let cart = RunningCart(mainLua: DemoCart.mainLua, ppu: DemoCart.ppuWithTiles())
    var input = Input()
    hold([.down, .right], for: frames, in: cart, input: &input)
    #expect(cart.error == nil)
    var frame = Framebuffer()
    cart.ppu.render(into: &frame)
    try expectFrameMatchesGolden(frame, named: name)
}

private func hold(_ buttons: [Button], for frames: Int, in cart: RunningCart, input: inout Input) {
    let held = buttons.reduce(UInt8(0)) { mask, button in mask | 1 << button.rawValue }
    for _ in 0..<frames {
        input.beginFrame(held: held)
        cart.runFrame(input: input)
    }
}
