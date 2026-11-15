import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let storage = JSObject.global.fesStorage
nonisolated(unsafe) private let shelfList = document.getElementById("shelf-list")
nonisolated(unsafe) private let playButton = document.getElementById("shelf-play")
nonisolated(unsafe) private let editButton = document.getElementById("shelf-edit")
nonisolated(unsafe) private let exportButton = document.getElementById("shelf-export")

let demoFolder = ""
nonisolated(unsafe) var selectedShelfFolder: String?

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
    if let folder = selectedShelfFolder {
        afterEarlierStorageWork {
            if await loadCart(folder: folder) {
                runCart()
            }
        }
    }
    return .undefined
}

nonisolated(unsafe) private let editClicked = JSClosure { _ in
    if let folder = selectedShelfFolder {
        afterEarlierStorageWork {
            if await loadCart(folder: folder) {
                showCodeView()
            }
        }
    }
    return .undefined
}

func startShelf() {
    _ = document.getElementById("show-shelf").addEventListener("click", showShelfClicked)
    _ = shelfList.addEventListener("click", shelfListClicked)
    _ = playButton.addEventListener("click", playClicked)
    _ = editButton.addEventListener("click", editClicked)
}

func showShelf() {
    show(.shelf)
    let selected = shelfList.querySelector("[aria-pressed=\"true\"]")
    _ = (selected.isNull ? shelfList.querySelector("button") : selected).focus()
}

func refreshShelf() async throws(JSException) {
    let folders = try await names(fromStorage: storage.listCartFolders())
    var entries: [(folder: String, name: String)] = []
    for folder in folders {
        entries.append((folder, await savedCartName(folder: folder) ?? "Damaged cart"))
    }
    entries.sort { ($0.name, $0.folder) < ($1.name, $1.folder) }
    showShelfEntries(entries)
}

func showShelfEntries(_ savedCarts: [(folder: String, name: String)]) {
    let entries = [(folder: demoFolder, name: "Built-in demo")] + savedCarts
    if !entries.contains(where: { $0.folder == selectedShelfFolder }) {
        selectedShelfFolder = nil
    }
    shelfList.textContent = ""
    for entry in entries {
        let button = document.createElement("button")
        button.type = "button"
        button.dataset.folder = .string(entry.folder)
        button.textContent = .string(entry.name)
        let item = document.createElement("li")
        _ = item.append(button)
        _ = shelfList.append(item)
    }
    showShelfSelection()
}

private func selectShelfEntry(folder: String) {
    selectedShelfFolder = folder
    showShelfSelection()
}

private func showShelfSelection() {
    let buttons = shelfList.querySelectorAll("[data-folder]")
    for index in 0..<Int(buttons.length.number!) {
        let button = buttons[index]
        let isSelected = string(from: button.dataset.folder) == selectedShelfFolder
        _ = button.setAttribute("aria-pressed", isSelected ? "true" : "false")
    }
    playButton.disabled = .boolean(selectedShelfFolder == nil)
    editButton.disabled = .boolean(selectedShelfFolder == nil)
    exportButton.disabled = .boolean(selectedShelfFolder == nil || selectedShelfFolder == demoFolder)
}
