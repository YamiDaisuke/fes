import Console

private let lineCount = 2 * PaletteBank.paletteCount

func paletteText(background: PaletteBank, sprites: PaletteBank) -> String {
    var text = ""
    for bank in [background, sprites] {
        for palette in 0..<PaletteBank.paletteCount {
            let entries = (0..<PaletteBank.colorsPerPalette).map { index in
                lowercaseHex(bank.mainPaletteIndex(palette: palette, index: index), digits: 2)
            }
            text += entries.joined(separator: " ") + "\n"
        }
    }
    return text
}

func parsePalettes(_ text: String, file: String) throws(CartFileError) -> (background: PaletteBank, sprites: PaletteBank) {
    var banks = [PaletteBank(), PaletteBank()]
    for (lineIndex, line) in try textLines(text, count: lineCount, file: file).enumerated() {
        let fields = try spaceSeparatedFields(
            line, count: PaletteBank.colorsPerPalette, file: file, lineNumber: lineIndex + 1, what: "entries")
        for (index, field) in fields.enumerated() {
            guard field.count == 2, let mainPaletteIndex = hexValue(field), mainPaletteIndex < MainPalette.colorCount else {
                throw CartFileError(
                    file: file, line: lineIndex + 1,
                    reason: "entry \(index + 1): expected a main palette index 00–3f, found \(field)")
            }
            banks[lineIndex / PaletteBank.paletteCount].setMainPaletteIndex(
                mainPaletteIndex, palette: lineIndex % PaletteBank.paletteCount, index: index)
        }
    }
    return (banks[0], banks[1])
}
