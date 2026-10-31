public struct Framebuffer: Equatable {
    public private(set) var rgba = [UInt8](repeating: 0, count: Screen.width * Screen.height * 4)

    public init() {}

    public mutating func setPixel(x: Int, y: Int, to color: Color) {
        let offset = (y * Screen.width + x) * 4
        rgba[offset] = color.red
        rgba[offset + 1] = color.green
        rgba[offset + 2] = color.blue
        rgba[offset + 3] = 255
    }
}
