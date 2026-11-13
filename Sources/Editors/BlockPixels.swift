import Console

public struct BlockPixels: Equatable {
    public let size: BlockSize
    public let colors: [Int]

    public func flippedHorizontally() -> BlockPixels {
        BlockPixels(size: size, colors: rows.flatMap { $0.reversed() })
    }

    public func flippedVertically() -> BlockPixels {
        BlockPixels(size: size, colors: rows.reversed().flatMap { $0 })
    }

    private var rows: [ArraySlice<Int>] {
        let side = TileBank.tileSize * size.rawValue
        return stride(from: 0, to: colors.count, by: side).map { colors[$0..<$0 + side] }
    }
}

extension TileBank {
    public func pixels(of block: TileBlock) -> BlockPixels {
        let side = block.pixelsPerSide
        let colors = (0..<side).flatMap { y in
            (0..<side).map { x in colorIndex(at: ArtPoint(x: x, y: y), in: block) }
        }
        return BlockPixels(size: block.size, colors: colors)
    }

    public mutating func paste(_ pixels: BlockPixels, atSelectedTile tile: Int) {
        let block = TileBlock(selectedTile: tile, size: pixels.size)
        let side = block.pixelsPerSide
        for (i, color) in pixels.colors.enumerated() {
            let pixel = block.tileAndPixel(at: ArtPoint(x: i % side, y: i / side))
            setPixel(tile: pixel.tile, x: pixel.x, y: pixel.y, color: color)
        }
    }
}
