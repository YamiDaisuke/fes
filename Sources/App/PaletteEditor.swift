import Console
import Editors
import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let artViewElement = document.getElementById("art-view")
nonisolated(unsafe) private let toggleButton = document.getElementById("art-palettes-toggle")
nonisolated(unsafe) private let entriesHeading = document.getElementById("art-palette-entries-heading")
nonisolated(unsafe) private let entryGroup = document.getElementById("art-palette-entries")
nonisolated(unsafe) private let mainColorHint = document.getElementById("art-main-hint")
nonisolated(unsafe) private let mainColorGroup = document.getElementById("art-main-colors")

nonisolated(unsafe) private var isPaletteEditorShown = false
nonisolated(unsafe) private var entryButtons: [[JSValue]] = []
nonisolated(unsafe) private var mainColorButtons: [JSValue] = []

nonisolated(unsafe) private let toggleClicked = JSClosure { _ in
    dropArtStroke()
    isPaletteEditorShown.toggle()
    _ = artViewElement.setAttribute("data-panel", isPaletteEditorShown ? "palettes" : "tile")
    _ = toggleButton.setAttribute("aria-pressed", isPaletteEditorShown ? "true" : "false")
    redrawArtView()
    return .undefined
}

nonisolated(unsafe) private let entryClicked = JSClosure { arguments in
    if let button = arguments[0].target.closest("[data-palette]").object,
       let palette = string(from: button.dataset.palette).flatMap({ Int($0) }),
       let color = string(from: button.dataset.color).flatMap({ Int($0) }),
       (0..<PaletteBank.paletteCount).contains(palette),
       (0..<PaletteBank.colorsPerPalette).contains(color) {
        artSelection.previewPalette = palette
        artSelection.color = color
        redrawArtView()
    }
    return .undefined
}

nonisolated(unsafe) private let mainColorClicked = JSClosure { arguments in
    let bank = artSelection.bank
    if let button = arguments[0].target.closest("[data-main-color]").object,
       let mainIndex = string(from: button.dataset.mainColor).flatMap({ Int($0) }),
       (0..<MainPalette.colorCount).contains(mainIndex),
       !bank.isTransparent(colorIndex: artSelection.color) {
        var palettes = cart.palettes(in: bank)
        palettes.setMainPaletteIndex(mainIndex, palette: artSelection.previewPalette, index: artSelection.color)
        cart.setPalettes(palettes, in: bank)
        keepRecoveryCopy()
        redrawArtView()
    }
    return .undefined
}

func startPaletteEditor() {
    for palette in 0..<PaletteBank.paletteCount {
        var paletteButtons: [JSValue] = []
        for color in 0..<PaletteBank.colorsPerPalette {
            let button = newButton()
            button.dataset.palette = .string(String(palette))
            button.dataset.color = .string(String(color))
            _ = entryGroup.append(button)
            paletteButtons.append(button)
        }
        entryButtons.append(paletteButtons)
    }
    for mainIndex in 0..<MainPalette.colorCount {
        let button = newButton()
        button.dataset.mainColor = .string(String(mainIndex))
        _ = mainColorGroup.append(button)
        mainColorButtons.append(button)
    }
    _ = toggleButton.addEventListener("click", toggleClicked)
    _ = entryGroup.addEventListener("click", entryClicked)
    _ = mainColorGroup.addEventListener("click", mainColorClicked)
}

func redrawPaletteEditor() {
    guard isPaletteEditorShown else { return }
    let bank = artSelection.bank
    let selectedPalette = artSelection.previewPalette
    let selectedColor = artSelection.color
    let palettes = cart.palettes(in: bank)
    let isSelectionTransparent = bank.isTransparent(colorIndex: selectedColor)

    entriesHeading.textContent = .string(bank == .background ? "Background palettes" : "Sprite palettes")
    mainColorHint.textContent = .string(isSelectionTransparent
        ? "Sprite color 0 is always transparent."
        : "Choose a main color for \(bank == .background ? "background" : "sprite") palette \(selectedPalette), color \(selectedColor).")

    for palette in 0..<PaletteBank.paletteCount {
        for color in 0..<PaletteBank.colorsPerPalette {
            let button = entryButtons[palette][color]
            let isTransparent = bank.isTransparent(colorIndex: color)
            _ = button.setAttribute("aria-label", cart.paletteEntryLabel(bank: bank, palette: palette, index: color))
            _ = button.setAttribute("aria-pressed", palette == selectedPalette && color == selectedColor ? "true" : "false")
            _ = button.classList.toggle("transparent", isTransparent)
            button.style.background = .string(isTransparent ? "" : cart.mainPalette[palettes.mainPaletteIndex(palette: palette, index: color)].hexCode)
        }
    }
    let assignedMainIndex = palettes.mainPaletteIndex(palette: selectedPalette, index: selectedColor)
    for mainIndex in 0..<MainPalette.colorCount {
        let button = mainColorButtons[mainIndex]
        _ = button.setAttribute("aria-label", cart.mainColorLabel(mainIndex))
        _ = button.setAttribute("aria-pressed", !isSelectionTransparent && mainIndex == assignedMainIndex ? "true" : "false")
        button.style.background = .string(cart.mainPalette[mainIndex].hexCode)
        button.disabled = .boolean(isSelectionTransparent)
    }
}

private func newButton() -> JSValue {
    let button = document.createElement("button")
    _ = button.setAttribute("type", "button")
    return button
}
