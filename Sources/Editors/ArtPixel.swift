import Console

let gridLineColor = Color(rgb: 0x303030)
let tileBorderColor = Color(rgb: 0x909090)
let selectionColor = Color(rgb: 0xffffff)
let checkerLightColor = Color(rgb: 0xb0b0b0)
let checkerDarkColor = Color(rgb: 0x808080)

extension RGBAImage {
    mutating func fillArtPixel(x: Int, y: Int, zoom: Int, color: Color?) {
        guard let color else {
            fillChecker(x: x, y: y, zoom: zoom)
            return
        }
        fill(x: x, y: y, width: zoom, height: zoom, color: color)
    }

    mutating func ringSquares(column: Int, row: Int, count: Int, in layout: GridLayout) {
        let left = layout.origin(ofSquare: column) - 1
        let top = layout.origin(ofSquare: row) - 1
        let side = count * (layout.squareSide + 1) + 1
        fill(x: left, y: top, width: side, height: 1, color: selectionColor)
        fill(x: left, y: top + side - 1, width: side, height: 1, color: selectionColor)
        fill(x: left, y: top, width: 1, height: side, color: selectionColor)
        fill(x: left + side - 1, y: top, width: 1, height: side, color: selectionColor)
    }

    private mutating func fillChecker(x: Int, y: Int, zoom: Int) {
        let half = zoom / 2
        fill(x: x, y: y, width: zoom, height: zoom, color: checkerLightColor)
        fill(x: x + half, y: y, width: zoom - half, height: half, color: checkerDarkColor)
        fill(x: x, y: y + half, width: half, height: zoom - half, color: checkerDarkColor)
    }
}
