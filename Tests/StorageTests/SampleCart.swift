import Console
import Storage

func sampleCart() -> Cart {
    var cart = Cart(name: "Ünï \"quoted\" cart 🎮", mainLua: "print(\"héllo\")\nx = 1\n")
    cart.backgroundTiles.setPixel(tile: 255, x: 7, y: 7, color: 7)
    cart.spriteTiles.setPixel(tile: 255, x: 7, y: 7, color: 3)
    cart.spritePalettes.setMainPaletteIndex(63, palette: 7, index: 7)
    cart.mainPalette[63] = Color(rgb: 0x0a0b0c)
    cart.mainPalette[0] = Color(rgb: 0xabcdef)
    cart.background[column: 31, row: 31] = Tilemap.Cell(tile: 255, palette: 7)
    return cart
}
