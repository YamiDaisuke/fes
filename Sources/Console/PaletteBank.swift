public struct PaletteBank {
    public static let paletteCount = 8
    public static let colorsPerPalette = 8

    private var masterIndices = Array(0..<(paletteCount * colorsPerPalette))

    public init() {}

    public func color(palette: Int, index: Int) -> Color {
        MasterPalette.colors[masterIndices[entry(palette, index)]]
    }

    public mutating func setMasterIndex(_ master: Int, palette: Int, index: Int) {
        masterIndices[entry(palette, index)] = master & 0x3F
    }

    private func entry(_ palette: Int, _ index: Int) -> Int {
        (palette & 0b111) * Self.colorsPerPalette + (index & 0b111)
    }
}
