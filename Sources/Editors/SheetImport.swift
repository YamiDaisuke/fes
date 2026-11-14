import Console
import Storage

public enum SheetImport: Equatable {
    case imported(CartArt)
    case refused([SheetProblem])
}

private let maxSheetSide = sheetColumns * TileBank.tileSize

enum ImagePixel: Equatable {
    case transparent
    case halfTransparent
    case opaque(Color)
}

extension Cart {
    public func sheetImport(width: Int, height: Int, rgba: [UInt8], bank: Bank, preferredPalette: Int) -> SheetImport {
        let imageProblems = wholeImageProblems(width: width, height: height, rgba: rgba)
        if !imageProblems.isEmpty {
            return .refused(imageProblems)
        }

        let mainColors = Set((0..<MainPalette.colorCount).map { mainPalette[$0] })
        let paletteOrder = [preferredPalette] + (0..<PaletteBank.paletteCount).filter { $0 != preferredPalette }
        let candidatePalettes = paletteOrder.map { previewColors(bank: bank, palette: $0) }

        var tiles = TileBank()
        var problems: [SheetProblem] = []
        for row in 0..<(height / TileBank.tileSize) {
            for column in 0..<(width / TileBank.tileSize) {
                let tile = SheetTile(column: column, row: row)
                let pixels = imagePixels(of: tile, width: width, rgba: rgba)
                let colors = distinctOpaqueColors(pixels)
                let pixelRules = pixelProblems(pixels, colors: colors, bank: bank, mainColors: mainColors)
                if !pixelRules.isEmpty {
                    problems += pixelRules.map { SheetProblem(rule: $0, tile: tile) }
                    continue
                }
                guard let positions = firstFit(colors, in: candidatePalettes) else {
                    problems.append(SheetProblem(rule: .fitsNoSubPalette(bank: bank), tile: tile))
                    continue
                }
                write(pixels, positions: positions, to: row * sheetColumns + column, in: &tiles)
            }
        }
        guard problems.isEmpty else { return .refused(problems) }
        var imported = self
        imported.setTiles(tiles, in: bank)
        return .imported(imported.art)
    }
}

func wholeImageProblems(width: Int, height: Int, rgba: [UInt8]) -> [SheetProblem] {
    let sizeProblems = sheetSizeProblems(width: width, height: height)
    if !sizeProblems.isEmpty {
        return sizeProblems
    }
    if rgba.count != width * height * 4 {
        return [SheetProblem(rule: .wrongByteCount(width: width, height: height, actual: rgba.count), tile: nil)]
    }
    return []
}

extension Bank {
    var opaqueColorsPerTile: Int {
        self == .sprite ? PaletteBank.colorsPerPalette - 1 : PaletteBank.colorsPerPalette
    }
}

public func sheetSizeProblems(width: Int, height: Int) -> [SheetProblem] {
    if width < 1 || height < 1 {
        return [SheetProblem(rule: .noPixels, tile: nil)]
    }
    var problems: [SheetProblem] = []
    if width % TileBank.tileSize != 0 || height % TileBank.tileSize != 0 {
        problems.append(SheetProblem(rule: .sizeNotMultipleOf8(width: width, height: height), tile: nil))
    }
    if width > maxSheetSide || height > maxSheetSide {
        problems.append(SheetProblem(rule: .tooLarge(width: width, height: height), tile: nil))
    }
    return problems
}

func imagePixels(of tile: SheetTile, width: Int, rgba: [UInt8]) -> [ImagePixel] {
    var pixels: [ImagePixel] = []
    for y in 0..<TileBank.tileSize {
        for x in 0..<TileBank.tileSize {
            let offset = ((tile.row * TileBank.tileSize + y) * width + tile.column * TileBank.tileSize + x) * 4
            switch rgba[offset + 3] {
            case 0: pixels.append(.transparent)
            case 255: pixels.append(.opaque(Color(red: rgba[offset], green: rgba[offset + 1], blue: rgba[offset + 2])))
            default: pixels.append(.halfTransparent)
            }
        }
    }
    return pixels
}

func distinctOpaqueColors(_ pixels: [ImagePixel]) -> [Color] {
    var colors: [Color] = []
    for case .opaque(let color) in pixels where !colors.contains(color) {
        colors.append(color)
    }
    return colors
}

private func pixelProblems(_ pixels: [ImagePixel], colors: [Color], bank: Bank, mainColors: Set<Color>) -> [SheetRule] {
    var rules: [SheetRule] = []
    if pixels.contains(.halfTransparent) {
        rules.append(.halfTransparent)
    }
    if bank == .background && pixels.contains(.transparent) {
        rules.append(.transparentInBackground)
    }
    let missing = colors.filter { !mainColors.contains($0) }
    if !missing.isEmpty {
        rules.append(.colorsNotInMainPalette(missing))
    }
    if colors.count > bank.opaqueColorsPerTile {
        rules.append(.tooManyColors(count: colors.count, bank: bank))
    }
    return rules
}

private func firstFit(_ colors: [Color], in candidatePalettes: [[Color?]]) -> [Color: Int]? {
    for palette in candidatePalettes {
        if let positions = positions(of: colors, in: palette) {
            return positions
        }
    }
    return nil
}

private func positions(of colors: [Color], in palette: [Color?]) -> [Color: Int]? {
    var positions: [Color: Int] = [:]
    for color in colors {
        guard let position = palette.firstIndex(of: color) else { return nil }
        positions[color] = position
    }
    return positions
}

private func write(_ pixels: [ImagePixel], positions: [Color: Int], to tile: Int, in tiles: inout TileBank) {
    for (i, pixel) in pixels.enumerated() {
        guard case .opaque(let color) = pixel, let position = positions[color] else { continue }
        tiles.setPixel(tile: tile, x: i % TileBank.tileSize, y: i / TileBank.tileSize, color: position)
    }
}
