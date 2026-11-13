import Console

public struct ArtPoint: Equatable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    var isInsideTile: Bool {
        (0..<TileBank.tileSize).contains(x) && (0..<TileBank.tileSize).contains(y)
    }
}

public func editAreaPixel(atX x: Int, y: Int, in layout: GridLayout) -> ArtPoint {
    ArtPoint(x: layout.unboundedSquare(at: x), y: layout.unboundedSquare(at: y))
}

public func linePoints(from start: ArtPoint, to end: ArtPoint) -> [ArtPoint] {
    let width = abs(end.x - start.x)
    let height = abs(end.y - start.y)
    let stepX = start.x < end.x ? 1 : -1
    let stepY = start.y < end.y ? 1 : -1
    var error = width - height
    var point = start
    var points = [point]
    while point != end {
        let doubledError = 2 * error
        if doubledError >= -height {
            error -= height
            point.x += stepX
        }
        if doubledError <= width {
            error += width
            point.y += stepY
        }
        points.append(point)
    }
    return points
}

public func colorIndex(at point: ArtPoint, tiles: TileBank, tile: Int) -> Int? {
    point.isInsideTile ? tiles.colorIndex(tile: tile, x: point.x, y: point.y) : nil
}

extension TileBank {
    public mutating func paintLine(tile: Int, from start: ArtPoint, to end: ArtPoint, color: Int) {
        for point in linePoints(from: start, to: end) where point.isInsideTile {
            setPixel(tile: tile, x: point.x, y: point.y, color: color)
        }
    }
}
