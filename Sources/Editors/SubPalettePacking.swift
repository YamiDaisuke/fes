import Console

func packSubPalettes(_ colorSets: [[Color]], capacity: Int) -> [[Color]] {
    let packable = colorSets.enumerated().filter { !$0.element.isEmpty && $0.element.count <= capacity }
    let largestFirst = packable.sorted { a, b in
        a.element.count != b.element.count ? a.element.count > b.element.count : a.offset < b.offset
    }

    var palettes: [[Color]] = []
    for (_, colors) in largestFirst {
        let fittingPalettes = palettes.indices.compactMap { palette -> (palette: Int, newColors: [Color])? in
            let newColors = colors.filter { !palettes[palette].contains($0) }
            return palettes[palette].count + newColors.count <= capacity ? (palette, newColors) : nil
        }
        if let best = fittingPalettes.min(by: { $0.newColors.count < $1.newColors.count }) {
            palettes[best.palette] += best.newColors
        } else if palettes.count < PaletteBank.paletteCount {
            palettes.append(colors)
        }
    }
    return palettes
}
