import Console

struct TestSheet {
    let width: Int
    let height: Int
    var rgba: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        rgba = [UInt8](repeating: 0, count: width * height * 4)
    }

    init(width: Int, height: Int, color: Color) {
        self.init(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                set(x: x, y: y, color: color)
            }
        }
    }

    mutating func set(x: Int, y: Int, color: Color, alpha: UInt8 = 255) {
        let offset = (y * width + x) * 4
        rgba[offset..<(offset + 4)] = [color.red, color.green, color.blue, alpha]
    }
}
