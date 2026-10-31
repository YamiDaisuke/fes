public struct Sprite: Equatable {
    public var x: Int
    public var y: Int
    public var tile: Int
    public var palette: Int
    public var isFlippedHorizontally: Bool
    public var isFlippedVertically: Bool
    public var isBehindBackground: Bool

    public init(
        x: Int,
        y: Int,
        tile: Int,
        palette: Int,
        isFlippedHorizontally: Bool = false,
        isFlippedVertically: Bool = false,
        isBehindBackground: Bool = false
    ) {
        self.x = x
        self.y = y
        self.tile = tile
        self.palette = palette
        self.isFlippedHorizontally = isFlippedHorizontally
        self.isFlippedVertically = isFlippedVertically
        self.isBehindBackground = isBehindBackground
    }
}
