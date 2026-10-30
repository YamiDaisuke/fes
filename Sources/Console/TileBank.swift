public struct TileBank {
    public static let tileCount = 256
    public static let tileSize = 8

    private var rows = [UInt32](repeating: 0, count: tileCount * tileSize)

    public init() {}

    public func colorIndices(tile: Int, y: Int) -> [Int] {
        let row = rows[rowIndex(tile: tile, y: y)]
        return (0..<Self.tileSize).map { x in Int(row >> shift(x: x)) & 0b111 }
    }

    public mutating func setPixel(tile: Int, x: Int, y: Int, color: Int) {
        let i = rowIndex(tile: tile, y: y)
        let pixelShift = shift(x: x)
        let rowWithPixelCleared = rows[i] & ~(UInt32(0b111) << pixelShift)
        rows[i] = rowWithPixelCleared | (UInt32(color & 0b111) << pixelShift)
    }

    private func rowIndex(tile: Int, y: Int) -> Int {
        (tile & 0xFF) * Self.tileSize + (y & 0b111)
    }

    private func shift(x: Int) -> Int {
        (7 - (x & 0b111)) * 3
    }
}
