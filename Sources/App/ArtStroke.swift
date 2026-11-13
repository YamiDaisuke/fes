import Console
import Editors
import JavaScriptKit

private struct Stroke {
    let tool: ArtTool
    let bank: Bank
    let block: TileBlock
    let tilesBefore: TileBank
    var lastPixel: ArtPoint
}

nonisolated(unsafe) private var stroke: Stroke?
nonisolated(unsafe) private var isArtRedrawScheduled = false

nonisolated(unsafe) let artStroked = JSClosure { arguments in
    switch string(from: arguments[0]) {
    case "start":
        if shownView == .art, let pixel = editAreaPixels(arguments[1])?.first {
            leavePixelControls()
            stroke = Stroke(
                tool: artSelection.tool, bank: artSelection.bank, block: artSelection.block,
                tilesBefore: cart.tiles(in: artSelection.bank), lastPixel: pixel)
            continueStroke(to: [pixel])
        }
    case "move":
        if stroke?.tool != .fill, let pixels = editAreaPixels(arguments[1]) {
            continueStroke(to: pixels)
        }
    case "end":
        finishStroke()
    case "cancel":
        if let stroke, stroke.tool.changesTiles {
            cart.setTiles(stroke.tilesBefore, in: stroke.bank)
            scheduleArtRedraw()
        }
        finishStroke()
    default:
        break
    }
    return .undefined
}

func dropArtStroke() {
    if stroke?.tool.changesTiles == true {
        keepRecoveryCopy()
    }
    stroke = nil
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
        applyArtTool(current.tool, block: current.block, from: current.lastPixel, to: pixel, tiles: &tiles)
        current.lastPixel = pixel
    }
    stroke = current
    cart.setTiles(tiles, in: current.bank)
    if tiles != tilesBefore || artSelection != selectionBefore {
        scheduleArtRedraw()
    }
}

func applyArtTool(_ tool: ArtTool, block: TileBlock, from start: ArtPoint, to end: ArtPoint, tiles: inout TileBank) {
    switch tool {
    case .pencil:
        tiles.paintLine(in: block, from: start, to: end, color: artSelection.color)
    case .picker:
        if block.contains(end) {
            artSelection.color = tiles.colorIndex(at: end, in: block)
        }
    case .fill:
        tiles.fill(in: block, from: end, color: artSelection.color)
    }
}

private func finishStroke() {
    switch stroke?.tool {
    case .pencil, .fill:
        keepRecoveryCopy()
    case .picker:
        artSelection.tool = .pencil
        scheduleArtRedraw()
    case nil:
        break
    }
    stroke = nil
}

private func scheduleArtRedraw() {
    guard !isArtRedrawScheduled else { return }
    isArtRedrawScheduled = true
    _ = JSObject.global.requestAnimationFrame!(artRedrawFrame)
}
