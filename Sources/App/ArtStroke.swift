import Console
import Editors
import JavaScriptKit

private struct Stroke {
    let tool: ArtTool
    let bank: Bank
    let tile: Int
    let tilesBefore: TileBank
    var lastPixel: ArtPoint
}

nonisolated(unsafe) private var stroke: Stroke?
nonisolated(unsafe) private var isArtRedrawScheduled = false

nonisolated(unsafe) let artStroked = JSClosure { arguments in
    guard let pixels = editAreaPixels(arguments[1]) else { return .undefined }
    switch string(from: arguments[0]) {
    case "start":
        if let pixel = pixels.first, shownView == .art {
            stroke = Stroke(
                tool: artSelection.tool, bank: artSelection.bank, tile: artSelection.tile,
                tilesBefore: cart.tiles(in: artSelection.bank), lastPixel: pixel)
            continueStroke(to: [pixel])
        }
    case "move":
        continueStroke(to: pixels)
    case "end":
        finishStroke()
    case "cancel":
        if let stroke, stroke.tool == .pencil {
            cart.setTiles(stroke.tilesBefore, in: stroke.bank)
            scheduleArtRedraw()
        }
        finishStroke()
    default:
        break
    }
    return .undefined
}

nonisolated(unsafe) private let artRedrawFrame = JSClosure { _ in
    isArtRedrawScheduled = false
    redrawArtView()
    return .undefined
}

private func editAreaPixels(_ positions: JSValue) -> [ArtPoint]? {
    guard let layout = shownEditLayout, let array = positions.object.flatMap(JSArray.init) else { return nil }
    let numbers = array.map { $0.number.flatMap { Int(exactly: $0) } }
    guard numbers.count % 2 == 0, !numbers.contains(nil) else { return nil }
    return stride(from: 0, to: numbers.count, by: 2).map { i in
        editAreaPixel(atX: numbers[i]!, y: numbers[i + 1]!, in: layout)
    }
}

private func continueStroke(to pixels: [ArtPoint]) {
    guard var current = stroke else { return }
    let selectionBefore = artSelection
    var tiles = cart.tiles(in: current.bank)
    let tilesBefore = tiles
    for pixel in pixels {
        switch current.tool {
        case .pencil:
            tiles.paintLine(tile: current.tile, from: current.lastPixel, to: pixel, color: artSelection.color)
        case .picker:
            artSelection.color = colorIndex(at: pixel, tiles: tiles, tile: current.tile) ?? artSelection.color
        }
        current.lastPixel = pixel
    }
    stroke = current
    if tiles != tilesBefore {
        cart.setTiles(tiles, in: current.bank)
        scheduleArtRedraw()
    }
    if artSelection != selectionBefore {
        scheduleArtRedraw()
    }
}

private func finishStroke() {
    if stroke?.tool == .picker {
        artSelection.tool = .pencil
        scheduleArtRedraw()
    }
    stroke = nil
}

private func scheduleArtRedraw() {
    guard !isArtRedrawScheduled else { return }
    isArtRedrawScheduled = true
    _ = JSObject.global.requestAnimationFrame!(artRedrawFrame)
}
