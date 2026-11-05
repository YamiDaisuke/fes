public struct PaletteBank: Equatable {
    public static let paletteCount = 8
    public static let colorsPerPalette = 8

    private var mainPaletteIndices = Array(0..<(paletteCount * colorsPerPalette))

    public init() {}

    public func mainPaletteIndex(palette: Int, index: Int) -> Int {
        mainPaletteIndices[entry(palette, index)]
    }

    public mutating func setMainPaletteIndex(_ mainPaletteIndex: Int, palette: Int, index: Int) {
        mainPaletteIndices[entry(palette, index)] = mainPaletteIndex & 0x3F
    }

    private func entry(_ palette: Int, _ index: Int) -> Int {
        (palette & 0b111) * Self.colorsPerPalette + (index & 0b111)
    }
}
