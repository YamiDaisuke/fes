import Console

public func editAreaLayout(fittingWidth width: Int, height: Int, block: TileBlock) -> GridLayout {
    .largest(squares: block.pixelsPerSide, pixelsPerSquare: 1, fittingWidth: width, height: height)
}

public func editAreaImage(tiles: TileBank, block: TileBlock, colors: [Color?], layout: GridLayout, cursor: ArtPoint?) -> RGBAImage {
    var image = RGBAImage(width: layout.side, height: layout.side, color: gridLineColor)
    for firstPixelOfTile in stride(from: TileBank.tileSize, to: block.pixelsPerSide, by: TileBank.tileSize) {
        let line = layout.origin(ofSquare: firstPixelOfTile) - 1
        image.fill(x: line, y: 1, width: 1, height: layout.side - 2, color: tileBorderColor)
        image.fill(x: 1, y: line, width: layout.side - 2, height: 1, color: tileBorderColor)
    }
    for y in 0..<block.pixelsPerSide {
        for x in 0..<block.pixelsPerSide {
            let color = colors[tiles.colorIndex(at: ArtPoint(x: x, y: y), in: block)]
            image.fillArtPixel(x: layout.origin(ofSquare: x), y: layout.origin(ofSquare: y), zoom: layout.zoom, color: color)
        }
    }
    if let cursor {
        image.ringSquares(column: cursor.x, row: cursor.y, count: 1, color: selectionColor, in: layout)
    }
    return image
}
