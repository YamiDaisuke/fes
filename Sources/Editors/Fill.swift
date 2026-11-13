import Console

extension TileBank {
    public mutating func fill(in block: TileBlock, from start: ArtPoint, color: Int) {
        guard block.contains(start) else { return }
        let regionColor = colorIndex(at: start, in: block)
        guard regionColor != color else { return }
        var pending = [start]
        while let point = pending.popLast() {
            guard block.contains(point), colorIndex(at: point, in: block) == regionColor else { continue }
            let pixel = block.tileAndPixel(at: point)
            setPixel(tile: pixel.tile, x: pixel.x, y: pixel.y, color: color)
            pending.append(ArtPoint(x: point.x + 1, y: point.y))
            pending.append(ArtPoint(x: point.x - 1, y: point.y))
            pending.append(ArtPoint(x: point.x, y: point.y + 1))
            pending.append(ArtPoint(x: point.x, y: point.y - 1))
        }
    }
}
