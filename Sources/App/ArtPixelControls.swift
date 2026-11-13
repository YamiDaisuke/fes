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
    dropArtStroke()
    let cursor = artSelection.cursor
    var tiles = cart.tiles(in: artSelection.bank)
    applyArtTool(artSelection.tool, block: artSelection.block, from: cursor, to: cursor, tiles: &tiles)
    cart.setTiles(tiles, in: artSelection.bank)
    keepRecoveryCopy()
    if artSelection.tool == .picker {
        artSelection.tool = .pencil
    }
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

func pullPixelCursorInsideBlock() {
    let lastPixel = artSelection.block.pixelsPerSide - 1
    let cursor = artSelection.cursor
    artSelection.cursor = ArtPoint(x: min(cursor.x, lastPixel), y: min(cursor.y, lastPixel))
}

func leavePixelControls() {
    if isPixelCursorShown {
        _ = document.activeElement.blur()
    }
}

func redrawPixelControls(tiles: TileBank) {
    let cursor = artSelection.cursor
    let block = artSelection.block
    let color = tiles.colorIndex(at: cursor, in: block)
    let lastPixel = String(block.pixelsPerSide - 1)
    // The browser clamps value to the old max, so max goes first.
    _ = columnSlider.setAttribute("max", lastPixel)
    _ = rowSlider.setAttribute("max", lastPixel)
    columnSlider.value = .string(String(cursor.x))
    rowSlider.value = .string(String(cursor.y))
    _ = columnSlider.setAttribute("aria-valuetext", "\(cursor.x), color \(color)")
    _ = rowSlider.setAttribute("aria-valuetext", "\(cursor.y), color \(color)")
    let applyLabel = artSelection.tool == .pencil ? "Paint pixel" : "Pick color"
    // WebKit sends no click if the pressed text is replaced before mouseup, and the focusin redraw runs in between.
    if string(from: applyButton.textContent) != applyLabel {
        applyButton.textContent = .string(applyLabel)
    }
}

private func pixelNumber(in slider: JSValue) -> Int? {
    guard let number = string(from: slider.value).flatMap({ Int($0) }), (0..<artSelection.block.pixelsPerSide).contains(number) else {
        return nil
    }
    return number
}
