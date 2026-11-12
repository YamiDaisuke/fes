import Console
import Editors
import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let pixelGroup = document.getElementById("art-pixel")
nonisolated(unsafe) private let columnSlider = document.getElementById("art-pixel-column")
nonisolated(unsafe) private let rowSlider = document.getElementById("art-pixel-row")
nonisolated(unsafe) private let applyButton = document.getElementById("art-pixel-apply")

nonisolated(unsafe) var isPixelCursorShown = false

nonisolated(unsafe) private let cursorMoved = JSClosure { _ in
    if let x = pixelNumber(in: columnSlider), let y = pixelNumber(in: rowSlider) {
        artSelection.cursor = ArtPoint(x: x, y: y)
        redrawArtView()
    }
    return .undefined
}

nonisolated(unsafe) private let applyClicked = JSClosure { _ in
    let cursor = artSelection.cursor
    var tiles = cart.tiles(in: artSelection.bank)
    applyArtTool(artSelection.tool, tile: artSelection.tile, from: cursor, to: cursor, tiles: &tiles)
    cart.setTiles(tiles, in: artSelection.bank)
    artSelection.tool = .pencil
    redrawArtView()
    return .undefined
}

nonisolated(unsafe) private let pixelFocusIn = JSClosure { _ in
    isPixelCursorShown = true
    redrawArtView()
    return .undefined
}

nonisolated(unsafe) private let pixelFocusOut = JSClosure { arguments in
    if pixelGroup.contains(arguments[0].relatedTarget).boolean != true {
        isPixelCursorShown = false
        redrawArtView()
    }
    return .undefined
}

func startPixelControls() {
    _ = columnSlider.addEventListener("input", cursorMoved)
    _ = rowSlider.addEventListener("input", cursorMoved)
    _ = applyButton.addEventListener("click", applyClicked)
    _ = pixelGroup.addEventListener("focusin", pixelFocusIn)
    _ = pixelGroup.addEventListener("focusout", pixelFocusOut)
}

func redrawPixelControls(tiles: TileBank) {
    let cursor = artSelection.cursor
    let color = tiles.colorIndex(tile: artSelection.tile, x: cursor.x, y: cursor.y)
    columnSlider.value = .string(String(cursor.x))
    rowSlider.value = .string(String(cursor.y))
    _ = columnSlider.setAttribute("aria-valuetext", "\(cursor.x), color \(color)")
    _ = rowSlider.setAttribute("aria-valuetext", "\(cursor.y), color \(color)")
    applyButton.textContent = .string(artSelection.tool == .pencil ? "Paint pixel" : "Pick color")
}

private func pixelNumber(in slider: JSValue) -> Int? {
    string(from: slider.value).flatMap { Int($0) }.flatMap { (0..<TileBank.tileSize).contains($0) ? $0 : nil }
}
