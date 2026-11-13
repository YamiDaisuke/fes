import Console

public enum BlockSize: Int, CaseIterable {
    case one = 1, two = 2, four = 4
}

public struct TileBlock: Equatable {
    public let firstTile: Int
    public let size: BlockSize

    public init(selectedTile: Int, size: BlockSize) {
        let lastFirstColumn = sheetColumns - size.rawValue
        let column = min(selectedTile % sheetColumns, lastFirstColumn)
        let row = min(selectedTile / sheetColumns, lastFirstColumn)
        firstTile = row * sheetColumns + column
        self.size = size
    }

    public var pixelsPerSide: Int { TileBank.tileSize * size.rawValue }

    public var tiles: [Int] {
        (0..<size.rawValue).flatMap { row in
            (0..<size.rawValue).map { column in firstTile + row * sheetColumns + column }
        }
    }

    public func contains(_ point: ArtPoint) -> Bool {
        (0..<pixelsPerSide).contains(point.x) && (0..<pixelsPerSide).contains(point.y)
    }

    public func tileAndPixel(at point: ArtPoint) -> (tile: Int, x: Int, y: Int) {
        let size = TileBank.tileSize
        let tile = firstTile + (point.y / size) * sheetColumns + point.x / size
        return (tile, point.x % size, point.y % size)
    }
}
