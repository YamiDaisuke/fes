import Console

public struct CartLabel: Equatable {
    public internal(set) var mainPaletteIndices: [UInt8]
}

extension CartLabel {
    public init(framebuffer: Framebuffer, mainPalette: MainPalette) {
        var exactIndices: [Color: UInt8] = [:]
        for index in (0..<MainPalette.colorCount).reversed() {
            exactIndices[mainPalette[index]] = UInt8(index)
        }
        mainPaletteIndices = []
        mainPaletteIndices.reserveCapacity(Screen.width * Screen.height)
        for pixel in 0..<(Screen.width * Screen.height) {
            let offset = pixel * 4
            let color = Color(
                red: framebuffer.rgba[offset], green: framebuffer.rgba[offset + 1], blue: framebuffer.rgba[offset + 2])
            mainPaletteIndices.append(exactIndices[color] ?? nearestIndex(to: color, in: mainPalette))
        }
    }
}

private func nearestIndex(to color: Color, in mainPalette: MainPalette) -> UInt8 {
    var nearest = 0
    var smallestDistance = Int.max
    for index in 0..<MainPalette.colorCount {
        let candidate = mainPalette[index]
        let red = Int(candidate.red) - Int(color.red)
        let green = Int(candidate.green) - Int(color.green)
        let blue = Int(candidate.blue) - Int(color.blue)
        let distance = red * red + green * green + blue * blue
        if distance < smallestDistance {
            nearest = index
            smallestDistance = distance
        }
    }
    return UInt8(nearest)
}
