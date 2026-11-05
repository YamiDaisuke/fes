import Console

func mapText(_ map: Tilemap) -> String {
    var text = ""
    for row in 0..<Tilemap.rows {
        let cells = (0..<Tilemap.columns).map { column in
            let cell = map[column: column, row: row]
            return lowercaseHex(cell.tile, digits: 2) + String(cell.palette)
        }
        text += cells.joined(separator: " ") + "\n"
    }
    return text
}

func parseMap(_ text: String, file: String) throws(CartFileError) -> Tilemap {
    var map = Tilemap()
    for (row, line) in try textLines(text, count: Tilemap.rows, file: file).enumerated() {
        let cells = try spaceSeparatedFields(line, count: Tilemap.columns, file: file, lineNumber: row + 1, what: "cells")
        for (column, cell) in cells.enumerated() {
            guard cell.count == 3,
                let tile = hexValue(cell.prefix(2)),
                let palette = Int(cell.suffix(1)), (0..<PaletteBank.paletteCount).contains(palette)
            else {
                throw CartFileError(
                    file: file, line: row + 1,
                    reason: "cell \(column + 1): expected two hex digits of tile and a palette 0–7, found \(cell)")
            }
            map[column: column, row: row] = Tilemap.Cell(tile: tile, palette: palette)
        }
    }
    return map
}
