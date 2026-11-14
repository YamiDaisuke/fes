import Console
import Storage

extension Cart {
    public func sheetImportAdoptingColors(width: Int, height: Int, rgba: [UInt8], bank: Bank) -> SheetImport {
        let imageProblems = wholeImageProblems(width: width, height: height, rgba: rgba)
        if !imageProblems.isEmpty {
            return .refused(imageProblems)
        }
        let colors = imageColors(rgba: rgba)
        if colors.count > MainPalette.colorCount {
            return .refused([SheetProblem(rule: .tooManyImageColors(count: colors.count), tile: nil)])
        }

        var adopted = self
        for (index, color) in colors.enumerated() {
            adopted.mainPalette[index] = color
        }
        let packed = packSubPalettes(tileColorSets(width: width, height: height, rgba: rgba), capacity: bank.opaqueColorsPerTile)
        adopted.setPalettes(adoptedPalettes(packed, imageColors: colors, bank: bank), in: bank)

        let outcome = adopted.sheetImport(width: width, height: height, rgba: rgba, bank: bank, preferredPalette: 0)
        guard case .refused(let problems) = outcome else { return outcome }
        return .refused(problems.map { problem in
            guard problem.rule == .fitsNoSubPalette(bank: bank) else { return problem }
            return SheetProblem(rule: .needsMorePalettes(bank: bank), tile: problem.tile)
        })
    }
}

private func imageColors(rgba: [UInt8]) -> [Color] {
    var colors: [Color] = []
    var seen = Set<Color>()
    for offset in stride(from: 0, to: rgba.count, by: 4) where rgba[offset + 3] == 255 {
        let color = Color(red: rgba[offset], green: rgba[offset + 1], blue: rgba[offset + 2])
        if seen.insert(color).inserted {
            colors.append(color)
        }
    }
    return colors
}

private func tileColorSets(width: Int, height: Int, rgba: [UInt8]) -> [[Color]] {
    var colorSets: [[Color]] = []
    for row in 0..<(height / TileBank.tileSize) {
        for column in 0..<(width / TileBank.tileSize) {
            let pixels = imagePixels(of: SheetTile(column: column, row: row), width: width, rgba: rgba)
            colorSets.append(distinctOpaqueColors(pixels))
        }
    }
    return colorSets
}

private func adoptedPalettes(_ packed: [[Color]], imageColors: [Color], bank: Bank) -> PaletteBank {
    var palettes = PaletteBank()
    for palette in 0..<PaletteBank.paletteCount {
        for index in 0..<PaletteBank.colorsPerPalette {
            palettes.setMainPaletteIndex(0, palette: palette, index: index)
        }
    }
    let firstEntry = bank.isTransparent(colorIndex: 0) ? 1 : 0
    for (palette, colors) in packed.enumerated() {
        for (position, color) in colors.enumerated() {
            palettes.setMainPaletteIndex(imageColors.firstIndex(of: color)!, palette: palette, index: firstEntry + position)
        }
    }
    return palettes
}
