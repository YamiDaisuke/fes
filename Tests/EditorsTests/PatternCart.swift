import Console
import Storage

func cartWithPatternTiles() -> Cart {
    var cart = Cart(name: "Pattern", mainLua: "")
    for tile in 0..<TileBank.tileCount {
        for y in 0..<TileBank.tileSize {
            for x in 0..<TileBank.tileSize {
                let color = (tile + x + y) % 8
                cart.backgroundTiles.setPixel(tile: tile, x: x, y: y, color: color)
                cart.spriteTiles.setPixel(tile: tile, x: x, y: y, color: color)
            }
        }
    }
    return cart
}
