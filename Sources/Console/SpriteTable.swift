public struct SpriteTable {
    public static let count = 64
    public static let maxPerScanline = 16

    private var entries = [Sprite?](repeating: nil, count: count)

    public init() {}

    public subscript(_ index: Int) -> Sprite? {
        get { entries[index & (Self.count - 1)] }
        set { entries[index & (Self.count - 1)] = newValue.map(masked) }
    }

    public func sprites(onScanline y: Int) -> [Sprite] {
        Array(entries.compactMap { $0 }.filter { isOnScreen($0, atScanline: y) }.prefix(Self.maxPerScanline))
    }

    private func isOnScreen(_ sprite: Sprite, atScanline y: Int) -> Bool {
        let size = TileBank.tileSize
        let coversScanline = sprite.y <= y && y < sprite.y + size
        let hasColumnOnScreen = -size < sprite.x && sprite.x < Screen.width
        return coversScanline && hasColumnOnScreen
    }

    private func masked(_ sprite: Sprite) -> Sprite {
        var sprite = sprite
        // 16-bit signed positions keep sprite.y + 8 and scanline - sprite.y from overflowing: docs/decisions/008-sprites.md
        sprite.x = Int(Int16(truncatingIfNeeded: sprite.x))
        sprite.y = Int(Int16(truncatingIfNeeded: sprite.y))
        sprite.tile &= 0xFF
        sprite.palette &= 0b111
        return sprite
    }
}
