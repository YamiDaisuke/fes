import Console

public func sheetReportImage(width: Int, height: Int, rgba: [UInt8], problems: [SheetProblem], layout: GridLayout) -> RGBAImage {
    var image = RGBAImage(width: layout.side, height: layout.side, color: gridLineColor)
    guard sheetSizeProblems(width: width, height: height).isEmpty, rgba.count == width * height * 4 else { return image }

    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            let isTransparent = rgba[offset + 3] == 0
            let color = isTransparent ? nil : Color(red: rgba[offset], green: rgba[offset + 1], blue: rgba[offset + 2])
            let left = layout.origin(ofSquare: x / TileBank.tileSize) + x % TileBank.tileSize * layout.zoom
            let top = layout.origin(ofSquare: y / TileBank.tileSize) + y % TileBank.tileSize * layout.zoom
            image.fillArtPixel(x: left, y: top, zoom: layout.zoom, color: color)
        }
    }

    let tileColumns = 0..<(width / TileBank.tileSize)
    let tileRows = 0..<(height / TileBank.tileSize)
    for case let tile? in problems.map(\.tile) where tileColumns.contains(tile.column) && tileRows.contains(tile.row) {
        image.ringSquares(column: tile.column, row: tile.row, count: 1, color: problemColor, in: layout)
    }
    return image
}
