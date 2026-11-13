import Console

public struct ArtPoint: Equatable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
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

extension TileBank {
    public func colorIndex(at point: ArtPoint, in block: TileBlock) -> Int {
        precondition(block.contains(point))
        let pixel = block.tileAndPixel(at: point)
        return colorIndex(tile: pixel.tile, x: pixel.x, y: pixel.y)
    }

    public mutating func paintLine(in block: TileBlock, from start: ArtPoint, to end: ArtPoint, color: Int) {
        for point in linePoints(from: start, to: end) where block.contains(point) {
            let pixel = block.tileAndPixel(at: point)
            setPixel(tile: pixel.tile, x: pixel.x, y: pixel.y, color: color)
        }
    }
}
