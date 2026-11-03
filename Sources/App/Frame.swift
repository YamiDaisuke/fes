import Console
import JavaScriptKit
import Runtime
import Storage

// The wasm build is single-threaded and only the JS frame loop calls frame().
nonisolated(unsafe) private var framebuffer = Framebuffer()
nonisolated(unsafe) private var input = Input()
nonisolated(unsafe) var cart = demoCart()
nonisolated(unsafe) var cartFolder: String?
nonisolated(unsafe) var runningCart = RunningCart(mainLua: cart.mainLua, ppu: cart.ppu)
nonisolated(unsafe) var isErrorShown = false

@_expose(wasm, "frame")
@c
func frame(heldButtons: UInt32) -> UnsafeRawPointer {
    input.beginFrame(held: UInt8(truncatingIfNeeded: heldButtons))
    runningCart.runFrame(input: input)
    if let error = runningCart.error, !isErrorShown {
        JSObject.global.document.getElementById("cart-error").textContent = .string(error)
        isErrorShown = true
    }
    runningCart.ppu.render(into: &framebuffer)
    // Valid until the next frame(): only frame() touches this private global, so its storage can't move before JS blits it.
    return framebuffer.rgba.withUnsafeBytes { $0.baseAddress! }
}

private func demoCart() -> Cart {
    var cart = Cart(name: "Demo", mainLua: JSObject.global.testCartMainLua.string ?? DemoCart.mainLua)
    let demoPPU = DemoCart.ppuWithTiles()
    cart.backgroundTiles = demoPPU.backgroundTiles
    cart.spriteTiles = demoPPU.spriteTiles
    return cart
}
