import Console

// The wasm build is single-threaded and only the JS frame loop calls frame().
nonisolated(unsafe) private var scene = TestScene()
nonisolated(unsafe) private var framebuffer = Framebuffer()
nonisolated(unsafe) private var frameNumber = 0

@_expose(wasm, "frame")
@c
func frame() -> UnsafeRawPointer {
    scene.render(frame: frameNumber, into: &framebuffer)
    frameNumber &+= 1
    // Valid until the next frame(): only frame() touches this private global, so its storage can't move before JS blits it.
    return framebuffer.rgba.withUnsafeBytes { $0.baseAddress! }
}
