import Console

public struct SheetTile: Equatable {
    public let column: Int
    public let row: Int
}

public enum SheetRule: Equatable {
    case noPixels
    case sizeNotMultipleOf8(width: Int, height: Int)
    case tooLarge(width: Int, height: Int)
    case wrongByteCount(width: Int, height: Int, actual: Int)
    case tooManyImageColors(count: Int)
    case halfTransparent
    case transparentInBackground
    case colorsNotInMainPalette([Color])
    case tooManyColors(count: Int, bank: Bank)
    case fitsNoSubPalette(bank: Bank)
    case needsMorePalettes(bank: Bank)
}

public struct SheetProblem: Equatable {
    public let rule: SheetRule
    public let tile: SheetTile?

    public var message: String {
        guard let tile else { return ruleText }
        let left = tile.column * TileBank.tileSize
        let top = tile.row * TileBank.tileSize
        return "Tile at column \(tile.column), row \(tile.row) (from pixel \(left), \(top)): \(ruleText)"
    }

    private var ruleText: String {
        switch rule {
        case .noPixels:
            "The image has no pixels."
        case .sizeNotMultipleOf8(let width, let height):
            "The image is \(width) × \(height) pixels. Both sides must be multiples of 8."
        case .tooLarge(let width, let height):
            "The image is \(width) × \(height) pixels. A sheet is at most 128 × 128."
        case .wrongByteCount(let width, let height, let actual):
            "The image data is \(actual) bytes, but \(width) × \(height) pixels need \(width * height * 4)."
        case .tooManyImageColors(let count):
            "The image has \(count) colors. The main palette holds \(MainPalette.colorCount)."
        case .halfTransparent:
            "some pixels are partly transparent. Use fully transparent or fully opaque pixels."
        case .transparentInBackground:
            "has transparent pixels. Background tiles can't be transparent."
        case .colorsNotInMainPalette(let colors):
            "colors not in the main palette: \(hexCodeList(colors))."
        case .tooManyColors(let count, .background):
            "\(count) colors. A background tile can use 8."
        case .tooManyColors(let count, .sprite):
            "\(count) colors. A sprite tile can use 7 plus transparent."
        case .fitsNoSubPalette(let bank):
            "its colors aren't all in one of the \(PaletteBank.paletteCount) \(bank.displayName.lowercased()) palettes."
        case .needsMorePalettes(let bank):
            "its colors don't fit in the \(PaletteBank.paletteCount) \(bank.displayName.lowercased()) palettes along with the other tiles' colors."
        }
    }
}

private func hexCodeList(_ colors: [Color]) -> String {
    let shownCount = 4
    let shown = colors.prefix(shownCount).map(\.hexCode).joined(separator: ", ")
    if colors.count > shownCount {
        return "\(shown) and \(colors.count - shownCount) more"
    }
    return shown
}
