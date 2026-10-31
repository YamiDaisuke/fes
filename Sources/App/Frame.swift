import Console
import JavaScriptKit
import Runtime

// The wasm build is single-threaded and only the JS frame loop calls frame().
nonisolated(unsafe) private var framebuffer = Framebuffer()
nonisolated(unsafe) private var input = Input()
nonisolated(unsafe) private let cart = RunningCart(
    mainLua: JSObject.global.testCartMainLua.string ?? DemoCart.mainLua,
    ppu: DemoCart.ppuWithTiles()
)
nonisolated(unsafe) private var isErrorShown = false

@_expose(wasm, "frame")
@c
func frame(heldButtons: UInt32) -> UnsafeRawPointer {
    input.beginFrame(held: UInt8(truncatingIfNeeded: heldButtons))
    cart.runFrame(input: input)
    if let error = cart.error, !isErrorShown {
        JSObject.global.document.getElementById("cart-error").textContent = .string(error)
        isErrorShown = true
    }
    cart.ppu.render(into: &framebuffer)
    // Valid until the next frame(): only frame() touches this private global, so its storage can't move before JS blits it.
    return framebuffer.rgba.withUnsafeBytes { $0.baseAddress! }
}
