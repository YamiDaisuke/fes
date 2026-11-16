import Console
import Editors
import JavaScriptKit
import Runtime
import Storage

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let shelfList = document.getElementById("shelf-list")
nonisolated(unsafe) private let playButton = document.getElementById("shelf-play")
nonisolated(unsafe) private let editButton = document.getElementById("shelf-edit")
nonisolated(unsafe) private let duplicateButton = document.getElementById("shelf-duplicate")
nonisolated(unsafe) private let exportButton = document.getElementById("shelf-export")
nonisolated(unsafe) private let deleteButton = document.getElementById("shelf-delete")

let demoFolder = ""
let damagedCartTitle = "Damaged cart"
nonisolated(unsafe) var selectedShelfFolder: String?
nonisolated(unsafe) private(set) var savedCartsOnShelf: [(folder: String, name: String?)] = []
nonisolated(unsafe) private let demoLabelImage = labelImageOfDemoStart()

nonisolated(unsafe) private let showShelfClicked = JSClosure { _ in
    showShelf()
    return .undefined
}

nonisolated(unsafe) private let shelfListClicked = JSClosure { arguments in
    if let button = arguments[0].target.closest("[data-folder]").object, let folder = string(from: button.dataset.folder) {
        selectShelfEntry(folder: folder)
    }
    return .undefined
}

nonisolated(unsafe) private let playClicked = JSClosure { _ in
    playSelectedCart()
    return .undefined
}

nonisolated(unsafe) private let editClicked = JSClosure { _ in
    editSelectedCart()
    return .undefined
}

func startShelf() {
    _ = document.getElementById("show-shelf").addEventListener("click", showShelfClicked)
    _ = shelfList.addEventListener("click", shelfListClicked)
    _ = playButton.addEventListener("click", playClicked)
    _ = editButton.addEventListener("click", editClicked)
    startShelfActions()
    showShelfEntries([], labelImages: [:])
}

func showShelf() {
    show(.shelf)
    focusShelfSelection()
}

func focusShelfSelection() {
    let selected = shelfList.querySelector("[aria-pressed=\"true\"]")
    _ = (selected.isNull ? shelfList.querySelector("button") : selected).focus()
}

func refreshShelf() async throws(JSException) {
    let savedCarts = try await savedCartEntries()
    var labelImages = [demoFolder: demoLabelImage]
    for savedCart in savedCarts {
        labelImages[savedCart.folder] = await savedCartLabelImage(folder: savedCart.folder)
    }
    showShelfEntries(savedCarts, labelImages: labelImages)
}

private func showShelfEntries(_ savedCarts: [(folder: String, name: String?)], labelImages: [String: RGBAImage]) {
    savedCartsOnShelf = savedCarts
    let entries = [(folder: demoFolder, name: "Built-in demo")] + savedCarts.map { (folder: $0.folder, name: $0.name ?? damagedCartTitle) }
    if !entries.contains(where: { $0.folder == selectedShelfFolder }) {
        selectedShelfFolder = nil
    }
    let listHadFocus = shelfList.contains(document.activeElement).boolean == true
    let focusedFolder = listHadFocus ? string(from: document.activeElement.dataset.folder) : nil
    var buttonToFocus: JSValue?
    shelfList.textContent = ""
    for entry in entries {
        let button = document.createElement("button")
        button.type = "button"
        button.dataset.folder = .string(entry.folder)
        let label = document.createElement("canvas")
        label.width = .number(Double(Screen.width))
        label.height = .number(Double(Screen.height))
        _ = label.setAttribute("aria-hidden", "true")
        if let image = labelImages[entry.folder] {
            blit(image, into: label)
        }
        let name = document.createElement("span")
        name.textContent = .string(entry.name)
        _ = button.append(label, name)
        if entry.folder == focusedFolder {
            buttonToFocus = button
        }
        let item = document.createElement("li")
        _ = item.append(button)
        _ = shelfList.append(item)
    }
    showShelfSelection()
    if let buttonToFocus {
        _ = buttonToFocus.focus()
    } else if listHadFocus {
        focusShelfSelection()
    }
}

private func selectShelfEntry(folder: String) {
    selectedShelfFolder = folder
    showShelfSelection()
    if savedCartsOnShelf.contains(where: { $0.folder == folder && $0.name == nil }) {
        showStatus("This cart's cart.json is missing or can't be read, so it can only be deleted.")
    }
}

private func showShelfSelection() {
    let buttons = shelfList.querySelectorAll("[data-folder]")
    for index in 0..<Int(buttons.length.number!) {
        let button = buttons[index]
        let isSelected = string(from: button.dataset.folder) == selectedShelfFolder
        _ = button.setAttribute("aria-pressed", isSelected ? "true" : "false")
    }
    playButton.disabled = .boolean(!canOpenSelection)
    editButton.disabled = .boolean(!canOpenSelection)
    duplicateButton.disabled = .boolean(!isNamedCartSelected)
    exportButton.disabled = .boolean(!isNamedCartSelected)
    deleteButton.disabled = .boolean(!savedCartsOnShelf.contains { $0.folder == selectedShelfFolder })
}

private var isNamedCartSelected: Bool {
    savedCartsOnShelf.contains { $0.folder == selectedShelfFolder && $0.name != nil }
}

private var canOpenSelection: Bool {
    selectedShelfFolder == demoFolder || isNamedCartSelected
}

private func playSelectedCart() {
    guard canOpenSelection, let folder = selectedShelfFolder else {
        return
    }
    afterEarlierStorageWork {
        if await loadCart(folder: folder) {
            runCart()
        }
    }
}

private func editSelectedCart() {
    guard canOpenSelection, let folder = selectedShelfFolder else {
        return
    }
    afterEarlierStorageWork {
        if await loadCart(folder: folder) {
            showCodeView()
        }
    }
}

func respondToShelfButtons(_ input: Input) {
    if input.wasPressedThisFrame(.left) {
        moveShelfSelection(by: -1)
    }
    if input.wasPressedThisFrame(.right) {
        moveShelfSelection(by: 1)
    }
    if input.wasPressedThisFrame(.a) {
        playSelectedCart()
    }
    if input.wasPressedThisFrame(.b) {
        editSelectedCart()
    }
}

private func moveShelfSelection(by step: Int) {
    let folders = [demoFolder] + savedCartsOnShelf.map(\.folder)
    let current = folders.firstIndex { $0 == selectedShelfFolder } ?? 0
    let target = min(max(current + step, 0), folders.count - 1)
    selectShelfEntry(folder: folders[target])
    let button = shelfList.querySelectorAll("[data-folder]")[target]
    _ = button.focus()
    _ = button.scrollIntoView(["block": "nearest", "inline": "nearest"])
}

private func labelImageOfDemoStart() -> RGBAImage {
    let demo = RunningCart(mainLua: DemoCart.mainLua, ppu: DemoCart.ppuWithTiles())
    demo.runFrame(input: Input())
    var framebuffer = Framebuffer()
    demo.ppu.render(into: &framebuffer)
    let mainPalette = demo.ppu.mainPalette
    return labelImage(CartLabel(framebuffer: framebuffer, mainPalette: mainPalette), mainPalette: mainPalette)
}
