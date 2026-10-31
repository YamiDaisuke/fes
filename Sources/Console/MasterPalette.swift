public enum MasterPalette {
    // Placeholder until the owner picks the 64 colors (docs/SPEC.md open decisions).
    public static let colors: [Color] = (0..<64).map { n in
        Color(red: level(n >> 4), green: level(n >> 2), blue: level(n))
    }

    private static func level(_ bits: Int) -> UInt8 {
        UInt8((bits & 0b11) * 85)
    }
}
