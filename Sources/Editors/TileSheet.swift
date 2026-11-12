import Console

public let sheetColumns = 16

public func tileSheetLayout(fittingWidth width: Int, height: Int) -> GridLayout {
    .largest(squares: sheetColumns, pixelsPerSquare: TileBank.tileSize, fittingWidth: width, height: height)
}

public func tileSheetImage(tiles: TileBank, colors: [Color?], selectedTile: Int, layout: GridLayout) -> RGBAImage {
    var image = RGBAImage(width: layout.side, height: layout.side, color: gridLineColor)
    for tile in 0..<TileBank.tileCount {
        let left = layout.origin(ofSquare: tile % sheetColumns)
        let top = layout.origin(ofSquare: tile / sheetColumns)
        for y in 0..<TileBank.tileSize {
            for x in 0..<TileBank.tileSize {
                let color = colors[tiles.colorIndex(tile: tile, x: x, y: y)]
                image.fillArtPixel(x: left + x * layout.zoom, y: top + y * layout.zoom, zoom: layout.zoom, color: color)
            }
        }
    }

    let ringTile = selectedTile & 0xFF
    image.ringSquare(column: ringTile % sheetColumns, row: ringTile / sheetColumns, in: layout)
    return image
}

public func sheetTile(atX x: Int, y: Int, in layout: GridLayout) -> Int? {
    guard let column = layout.square(at: x), let row = layout.square(at: y) else { return nil }
    return row * sheetColumns + column
}
