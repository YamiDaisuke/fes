import Console
import Editors
import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let colorPicker = document.getElementById("art-main-color-picker")
nonisolated(unsafe) private let colorPickerLabel = document.getElementById("art-main-color-picker-label")
nonisolated(unsafe) private let resetButton = document.getElementById("art-main-palette-reset")

nonisolated(unsafe) private let colorPicked = JSClosure { _ in
    guard let mainIndex = selectedMainIndex() else { return .undefined }
    let value = string(from: colorPicker.value) ?? ""
    if let color = Color(hexCode: value) {
        let artBefore = cart.art
        cart.mainPalette[mainIndex] = color
        recordArtEdit("main color \(mainIndex)", before: artBefore, merging: true)
    } else {
        showStatus("Can't use the color \(value): expected #rrggbb")
    }
    scheduleArtRedraw()
    return .undefined
}

nonisolated(unsafe) private let colorPickerOpened = JSClosure { _ in
    stopArtHistoryMerging()
    return .undefined
}

nonisolated(unsafe) private let resetClicked = JSClosure { _ in
    let artBefore = cart.art
    cart.mainPalette = MainPalette()
    showStatus("Reset the main palette.")
    recordArtEdit("main palette reset", before: artBefore)
    redrawArtView()
    return .undefined
}

func startMainColorEditor() {
    _ = colorPicker.addEventListener("input", colorPicked)
    _ = colorPicker.addEventListener("click", colorPickerOpened)
    _ = resetButton.addEventListener("click", resetClicked)
}

func redrawMainColorEditor() {
    if let mainIndex = selectedMainIndex() {
        colorPickerLabel.textContent = .string("Edit main color \(mainIndex)")
        colorPicker.disabled = .boolean(false)
        let hexCode = cart.mainPalette[mainIndex].hexCode
        if string(from: colorPicker.value) != hexCode {
            colorPicker.value = .string(hexCode)
        }
    } else {
        colorPickerLabel.textContent = .string("Edit main color")
        colorPicker.disabled = .boolean(true)
    }
    resetButton.disabled = .boolean(cart.mainPalette == MainPalette())
}

private func selectedMainIndex() -> Int? {
    let bank = artSelection.bank
    guard !bank.isTransparent(colorIndex: artSelection.color) else { return nil }
    return cart.palettes(in: bank).mainPaletteIndex(palette: artSelection.previewPalette, index: artSelection.color)
}
