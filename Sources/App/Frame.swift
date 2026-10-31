import Console

// The wasm build is single-threaded and only the JS frame loop calls frame().
nonisolated(unsafe) private var scene = TestScene()
nonisolated(unsafe) private var framebuffer = Framebuffer()
nonisolated(unsafe) private var frameNumber = 0
nonisolated(unsafe) private var input = Input()

@_expose(wasm, "frame")
@c
func frame(heldButtons: UInt32) -> UnsafeRawPointer {
    input.beginFrame(held: UInt8(truncatingIfNeeded: heldButtons))
    scene.render(frame: frameNumber, input: input, into: &framebuffer)
    frameNumber &+= 1
    // Valid until the next frame(): only frame() touches this private global, so its storage can't move before JS blits it.
    return framebuffer.rgba.withUnsafeBytes { $0.baseAddress! }
}
