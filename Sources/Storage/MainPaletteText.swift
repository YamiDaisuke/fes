import Console

func mainPaletteText(_ palette: MainPalette) -> String {
    var text = ""
    for index in 0..<MainPalette.colorCount {
        let color = palette[index]
        let rgb = Int(color.red) << 16 | Int(color.green) << 8 | Int(color.blue)
        text += lowercaseHex(rgb, digits: 6) + "\n"
    }
    return text
}

func parseMainPalette(_ text: String, file: String) throws(CartFileError) -> MainPalette {
    var palette = MainPalette()
    for (index, line) in try textLines(text, count: MainPalette.colorCount, file: file).enumerated() {
        guard line.count == 6, let rgb = hexValue(line) else {
            throw CartFileError(file: file, line: index + 1, reason: "expected a color rrggbb, found \(line)")
        }
        palette[index] = Color(rgb: rgb)
    }
    return palette
}
