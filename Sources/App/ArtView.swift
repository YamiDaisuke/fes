import Console
import Editors
import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let artView = JSObject.global.fesArtView
nonisolated(unsafe) private let sheetArea = document.getElementById("art-sheet-area")
nonisolated(unsafe) private let editArea = document.getElementById("art-edit-area")
nonisolated(unsafe) private let sheetCanvas = document.getElementById("art-sheet")
nonisolated(unsafe) private let editCanvas = document.getElementById("art-edit")
nonisolated(unsafe) private let bankGroup = document.getElementById("art-bank")
nonisolated(unsafe) private let paletteGroup = document.getElementById("art-palette")
nonisolated(unsafe) private let toolGroup = document.getElementById("art-tool")
nonisolated(unsafe) private let colorGroup = document.getElementById("art-colors")
nonisolated(unsafe) private let tileSlider = document.getElementById("art-tile")
nonisolated(unsafe) private let tileNumber = document.getElementById("art-tile-number")

nonisolated(unsafe) var artSelection = ArtSelection()
nonisolated(unsafe) private var shownSheetLayout: GridLayout?
nonisolated(unsafe) var shownEditLayout: GridLayout?

nonisolated(unsafe) private let artClicked = JSClosure { _ in
    show(.art)
    redrawArtView()
    _ = tileSlider.focus()
    return .undefined
}

nonisolated(unsafe) private let bankClicked = JSClosure { arguments in
    if let button = arguments[0].target.closest("[data-bank]").object,
       let bank = string(from: button.dataset.bank).flatMap(Bank.init(rawValue:)) {
        artSelection.bank = bank
        redrawArtView()
    }
    return .undefined
}

nonisolated(unsafe) private let paletteClicked = JSClosure { arguments in
    if let button = arguments[0].target.closest("[data-palette]").object,
       let palette = string(from: button.dataset.palette).flatMap({ Int($0) }),
       (0..<PaletteBank.paletteCount).contains(palette) {
        artSelection.previewPalette = palette
        redrawArtView()
    }
    return .undefined
}

nonisolated(unsafe) private let toolClicked = JSClosure { arguments in
    if let button = arguments[0].target.closest("[data-tool]").object,
       let tool = string(from: button.dataset.tool).flatMap(ArtTool.init(rawValue:)) {
        artSelection.tool = tool
        redrawArtView()
    }
    return .undefined
}

nonisolated(unsafe) private let colorClicked = JSClosure { arguments in
    if let button = arguments[0].target.closest("[data-color]").object,
       let color = string(from: button.dataset.color).flatMap({ Int($0) }),
       (0..<PaletteBank.colorsPerPalette).contains(color) {
        artSelection.color = color
        redrawArtView()
    }
    return .undefined
}

nonisolated(unsafe) private let tileChanged = JSClosure { _ in
    if let tile = string(from: tileSlider.value).flatMap({ Int($0) }), (0..<TileBank.tileCount).contains(tile) {
        artSelection.tile = tile
        redrawArtView()
    }
    return .undefined
}

nonisolated(unsafe) private let sheetTapped = JSClosure { arguments in
    if let layout = shownSheetLayout,
       let x = arguments[0].number.flatMap({ Int(exactly: $0) }),
       let y = arguments[1].number.flatMap({ Int(exactly: $0) }),
       let tile = sheetTile(atX: x, y: y, in: layout) {
        artSelection.tile = tile
        redrawArtView()
    }
    return .undefined
}

nonisolated(unsafe) private let artResized = JSClosure { _ in
    redrawArtView()
    return .undefined
}

func startArtView() {
    _ = document.getElementById("show-art").addEventListener("click", artClicked)
    _ = bankGroup.addEventListener("click", bankClicked)
    _ = paletteGroup.addEventListener("click", paletteClicked)
    _ = toolGroup.addEventListener("click", toolClicked)
    _ = colorGroup.addEventListener("click", colorClicked)
    _ = tileSlider.addEventListener("input", tileChanged)
    _ = artView.onTap(sheetCanvas, sheetTapped)
    _ = artView.onStroke(editCanvas, artStroked)
    startPixelControls()
    let resizeObserver = JSObject.global.ResizeObserver.function!.new(artResized)
    _ = resizeObserver.observe!(sheetArea)
    _ = resizeObserver.observe!(editArea)
}

func redrawArtView() {
    guard shownView == .art else { return }
    let sheetBox = flooredSize(of: sheetArea)
    let editBox = flooredSize(of: editArea)
    let sheetLayout = tileSheetLayout(fittingWidth: sheetBox.width, height: sheetBox.height)
    let editLayout = editAreaLayout(fittingWidth: editBox.width, height: editBox.height)
    let tiles = cart.tiles(in: artSelection.bank)
    let colors = cart.previewColors(bank: artSelection.bank, palette: artSelection.previewPalette)
    let tile = artSelection.tile
    blit(tileSheetImage(tiles: tiles, colors: colors, selectedTile: tile, layout: sheetLayout), into: sheetCanvas)
    let cursor = isPixelCursorShown ? artSelection.cursor : nil
    blit(editAreaImage(tiles: tiles, tile: tile, colors: colors, layout: editLayout, cursor: cursor), into: editCanvas)
    shownSheetLayout = sheetLayout
    shownEditLayout = editLayout

    for bank in Bank.allCases {
        setPressed(bankGroup.querySelector("[data-bank='\(bank.rawValue)']"), bank == artSelection.bank)
    }
    for palette in 0..<PaletteBank.paletteCount {
        setPressed(paletteGroup.querySelector("[data-palette='\(palette)']"), palette == artSelection.previewPalette)
    }
    for tool in ArtTool.allCases {
        setPressed(toolGroup.querySelector("[data-tool='\(tool.rawValue)']"), tool == artSelection.tool)
    }
    for (index, color) in colors.enumerated() {
        let button = colorGroup.querySelector("[data-color='\(index)']")
        setPressed(button, index == artSelection.color)
        _ = button.setAttribute("aria-label", color == nil ? "Color \(index), transparent" : "Color \(index)")
        _ = button.classList.toggle("transparent", color == nil)
        button.style.background = .string(color.map { "rgb(\($0.red) \($0.green) \($0.blue))" } ?? "")
    }
    tileSlider.value = .string(String(tile))
    _ = tileSlider.setAttribute("aria-valuetext", "\(tile), column \(tile % sheetColumns), row \(tile / sheetColumns)")
    tileNumber.textContent = .string(String(tile))
    redrawPixelControls(tiles: tiles)
}

private func flooredSize(of element: JSValue) -> (width: Int, height: Int) {
    let box = element.getBoundingClientRect()
    return (Int(box.width.number!.rounded(.down)), Int(box.height.number!.rounded(.down)))
}

private func setPressed(_ button: JSValue, _ isPressed: Bool) {
    _ = button.setAttribute("aria-pressed", isPressed ? "true" : "false")
}

private func blit(_ image: RGBAImage, into canvas: JSValue) {
    canvas.width = .number(Double(image.width))
    canvas.height = .number(Double(image.height))
    // The address is valid only during this call, so fesArtView.blit copies the pixels before returning.
    image.rgba.withUnsafeBytes { bytes in
        _ = artView.blit(canvas, Double(UInt(bitPattern: bytes.baseAddress)))
    }
}
