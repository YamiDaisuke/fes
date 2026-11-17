import Console

let problemColor = Color(rgb: 0xff3030)

// These mirror tokens in web/style.css by hand (decision 051).
let gridLineColor = Color(rgb: 0x7a6e9a)
let tileBorderColor = Color(rgb: 0x2a2438)
let selectionOutsideColor = Color(rgb: 0x2a2438)
let selectionInsideColor = Color(rgb: 0xffe9a8)
let checkerLightColor = Color(rgb: 0xece7f5)
let checkerDarkColor = Color(rgb: 0xa79bc4)

extension RGBAImage {
    mutating func fillArtPixel(x: Int, y: Int, zoom: Int, color: Color?) {
        guard let color else {
            fillChecker(x: x, y: y, zoom: zoom)
            return
        }
        fill(x: x, y: y, width: zoom, height: zoom, color: color)
    }

    mutating func ringSquares(column: Int, row: Int, count: Int, color: Color, in layout: GridLayout) {
        ring(left: layout.origin(ofSquare: column) - 1, top: layout.origin(ofSquare: row) - 1,
             side: count * (layout.squareSide + 1) + 1, color: color)
    }

    mutating func ringSelection(column: Int, row: Int, count: Int, in layout: GridLayout) {
        ringSquares(column: column, row: row, count: count, color: selectionOutsideColor, in: layout)
        ring(left: layout.origin(ofSquare: column), top: layout.origin(ofSquare: row),
             side: count * (layout.squareSide + 1) - 1, color: selectionInsideColor)
    }

    private mutating func ring(left: Int, top: Int, side: Int, color: Color) {
        fill(x: left, y: top, width: side, height: 1, color: color)
        fill(x: left, y: top + side - 1, width: side, height: 1, color: color)
        fill(x: left, y: top, width: 1, height: side, color: color)
        fill(x: left + side - 1, y: top, width: 1, height: side, color: color)
    }

    private mutating func fillChecker(x: Int, y: Int, zoom: Int) {
        let half = zoom / 2
        fill(x: x, y: y, width: zoom, height: zoom, color: checkerLightColor)
        fill(x: x + half, y: y, width: zoom - half, height: half, color: checkerDarkColor)
        fill(x: x, y: y + half, width: half, height: zoom - half, color: checkerDarkColor)
    }
}
