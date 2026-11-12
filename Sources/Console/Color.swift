public struct Color: Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(rgb: Int) {
        red = UInt8(truncatingIfNeeded: rgb >> 16)
        green = UInt8(truncatingIfNeeded: rgb >> 8)
        blue = UInt8(truncatingIfNeeded: rgb)
    }
}
