import Console

public struct RGBAImage: Equatable {
    public let width: Int
    public let height: Int
    public private(set) var rgba: [UInt8]

    init(width: Int, height: Int, color: Color) {
        self.width = width
        self.height = height
        rgba = [UInt8](repeating: 255, count: width * height * 4)
        fill(x: 0, y: 0, width: width, height: height, color: color)
    }

    mutating func fill(x: Int, y: Int, width fillWidth: Int, height fillHeight: Int, color: Color) {
        for row in y..<(y + fillHeight) {
            for column in x..<(x + fillWidth) {
                let offset = (row * width + column) * 4
                rgba[offset] = color.red
                rgba[offset + 1] = color.green
                rgba[offset + 2] = color.blue
                rgba[offset + 3] = 255
            }
        }
    }
}
