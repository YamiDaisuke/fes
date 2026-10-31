import Console
import Testing

private func mask(_ buttons: Button...) -> UInt8 {
    buttons.reduce(0) { $0 | 1 << $1.rawValue }
}

@Test func pressIsReportedOnlyOnTheFirstFrameAButtonIsHeld() {
    var input = Input()
    var pressed: [Bool] = []
    var held: [Bool] = []
    for _ in 0..<3 {
        input.beginFrame(held: mask(.a))
        pressed.append(input.wasPressedThisFrame(.a))
        held.append(input.isHeld(.a))
    }
    #expect(pressed == [true, false, false])
    #expect(held == [true, true, true])
}

@Test func releasingAndPressingAgainIsANewPress() {
    var input = Input()
    var pressed: [Bool] = []
    for frame in [mask(.a), mask(), mask(.a)] {
        input.beginFrame(held: frame)
        pressed.append(input.wasPressedThisFrame(.a))
    }
    #expect(pressed == [true, false, true])
}

@Test func eachButtonHasItsOwnEdge() {
    var input = Input()
    input.beginFrame(held: mask(.a))
    input.beginFrame(held: mask(.a, .b))
    #expect(input.wasPressedThisFrame(.b))
    #expect(!input.wasPressedThisFrame(.a))
    #expect(input.isHeld(.a))
}

@Test func bitmaskBitsFollowTheButtonOrderSharedWithJavaScript() {
    let javaScriptOrder: [Button] = [.left, .right, .up, .down, .a, .b, .start, .select]
    for (bit, expected) in javaScriptOrder.enumerated() {
        var input = Input()
        input.beginFrame(held: 1 << bit)
        #expect(Button.allCases.filter(input.isHeld) == [expected])
    }
}
