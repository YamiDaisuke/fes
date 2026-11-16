import Console

func labelText(_ label: CartLabel) -> String {
    var bytes: [UInt8] = []
    bytes.reserveCapacity(Screen.height * (Screen.width * 2 + 1))
    for row in 0..<Screen.height {
        for index in label.mainPaletteIndices[(row * Screen.width)..<((row + 1) * Screen.width)] {
            bytes.append(hexDigits[Int(index >> 4)])
            bytes.append(hexDigits[Int(index & 0xF)])
        }
        bytes.append(UInt8(ascii: "\n"))
    }
    return String(decoding: bytes, as: UTF8.self)
}

func parseLabel(_ text: String, file: String) throws(CartFileError) -> CartLabel {
    var indices: [UInt8] = []
    indices.reserveCapacity(Screen.width * Screen.height)
    for (row, line) in try textLines(text, count: Screen.height, file: file).enumerated() {
        guard line.count == Screen.width * 2 else {
            throw CartFileError(
                file: file, line: row + 1, reason: "expected \(Screen.width * 2) hex digits, found \(line.count)")
        }
        let characters = Array(line)
        for pairStart in stride(from: 0, to: characters.count, by: 2) {
            let pair = String(characters[pairStart...(pairStart + 1)])
            guard let index = hexValue(Substring(pair)), index < MainPalette.colorCount else {
                throw CartFileError(
                    file: file, line: row + 1,
                    reason: "column \(pairStart + 1): expected a main palette index 00–3f, found \(pair)")
            }
            indices.append(UInt8(index))
        }
    }
    return CartLabel(mainPaletteIndices: indices)
}
