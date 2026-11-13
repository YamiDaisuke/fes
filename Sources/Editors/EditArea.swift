import Console

public func editAreaLayout(fittingWidth width: Int, height: Int) -> GridLayout {
    .largest(squares: TileBank.tileSize, pixelsPerSquare: 1, fittingWidth: width, height: height)
}

public func editAreaImage(tiles: TileBank, tile: Int, colors: [Color?], layout: GridLayout, cursor: ArtPoint?) -> RGBAImage {
    var image = RGBAImage(width: layout.side, height: layout.side, color: gridLineColor)
    for y in 0..<TileBank.tileSize {
        for x in 0..<TileBank.tileSize {
            let color = colors[tiles.colorIndex(tile: tile, x: x, y: y)]
            image.fillArtPixel(x: layout.origin(ofSquare: x), y: layout.origin(ofSquare: y), zoom: layout.zoom, color: color)
        }
    }
    if let cursor {
        image.ringSquare(column: cursor.x, row: cursor.y, in: layout)
    }
    return image
}
