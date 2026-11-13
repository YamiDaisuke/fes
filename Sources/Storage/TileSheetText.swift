import Console

private let tilesPerRow = 16
private let sheetSide = tilesPerRow * TileBank.tileSize

func tileSheetText(_ bank: TileBank) -> String {
    var bytes: [UInt8] = []
    bytes.reserveCapacity(sheetSide * (sheetSide + 1))
    for sheetY in 0..<sheetSide {
        for sheetX in 0..<sheetSide {
            let pixel = sheetPixel(sheetX, sheetY)
            bytes.append(UInt8(ascii: "0") + UInt8(bank.colorIndex(tile: pixel.tile, x: pixel.x, y: pixel.y)))
        }
        bytes.append(UInt8(ascii: "\n"))
    }
    return String(decoding: bytes, as: UTF8.self)
}

func parseTileSheet(_ text: String, file: String) throws(CartFileError) -> TileBank {
    var bank = TileBank()
    for (sheetY, line) in try textLines(text, count: sheetSide, file: file).enumerated() {
        guard line.count == sheetSide else {
            throw CartFileError(
                file: file, line: sheetY + 1, reason: "expected \(sheetSide) digits, found \(line.count)")
        }
        for (sheetX, character) in line.enumerated() {
            guard let ascii = character.asciiValue, (UInt8(ascii: "0")...UInt8(ascii: "7")).contains(ascii) else {
                throw CartFileError(
                    file: file, line: sheetY + 1,
                    reason: "column \(sheetX + 1): expected a color 0–7, found \(character)")
            }
            let pixel = sheetPixel(sheetX, sheetY)
            bank.setPixel(tile: pixel.tile, x: pixel.x, y: pixel.y, color: Int(ascii - UInt8(ascii: "0")))
        }
    }
    return bank
}

private func sheetPixel(_ sheetX: Int, _ sheetY: Int) -> (tile: Int, x: Int, y: Int) {
    let size = TileBank.tileSize
    return ((sheetY / size) * tilesPerRow + sheetX / size, sheetX % size, sheetY % size)
}
