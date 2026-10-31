// The order is the bitmask shared with web/input.js: docs/decisions/009-input.md
public enum Button: Int, CaseIterable, Sendable {
    case left, right, up, down, a, b, start, select
}

public struct Input {
    private var held: UInt8 = 0
    private var heldLastFrame: UInt8 = 0

    public init() {}

    public mutating func beginFrame(held buttons: UInt8) {
        heldLastFrame = held
        held = buttons
    }

    public func isHeld(_ button: Button) -> Bool {
        held & bit(button) != 0
    }

    public func wasPressedThisFrame(_ button: Button) -> Bool {
        isHeld(button) && heldLastFrame & bit(button) == 0
    }

    private func bit(_ button: Button) -> UInt8 {
        1 << button.rawValue
    }
}
