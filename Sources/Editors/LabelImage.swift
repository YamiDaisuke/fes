import Console
import Storage

public func labelImage(_ label: CartLabel, mainPalette: MainPalette) -> RGBAImage {
    var image = RGBAImage(width: Screen.width, height: Screen.height, color: mainPalette[0])
    for (pixel, index) in label.mainPaletteIndices.enumerated() {
        image.fill(x: pixel % Screen.width, y: pixel / Screen.width, width: 1, height: 1, color: mainPalette[Int(index)])
    }
    return image
}
