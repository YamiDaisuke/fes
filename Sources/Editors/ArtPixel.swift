import Console

let gridLineColor = Color(rgb: 0x303030)
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

    private mutating func fillChecker(x: Int, y: Int, zoom: Int) {
        let half = zoom / 2
        fill(x: x, y: y, width: zoom, height: zoom, color: checkerLightColor)
        fill(x: x + half, y: y, width: zoom - half, height: half, color: checkerDarkColor)
        fill(x: x, y: y + half, width: half, height: zoom - half, color: checkerDarkColor)
    }
}
