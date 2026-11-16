import JavaScriptKit
import Storage

nonisolated(unsafe) private let document = JSObject.global.document

nonisolated(unsafe) private let newCartClicked = JSClosure { _ in
    afterEarlierStorageWork {
        guard await unsavedChangesMayBeDiscarded() else {
            return
        }
        openCart(newCart(), folder: nil)
        showStatus("Opened a new cart.")
        showCodeView()
    }
    return .undefined
}

nonisolated(unsafe) private let duplicateClicked = JSClosure { _ in
    if let folder = selectedShelfFolder, folder != demoFolder {
        afterEarlierStorageWork { await duplicateCart(folder: folder) }
    }
    return .undefined
}

nonisolated(unsafe) private let deleteClicked = JSClosure { _ in
    if let folder = selectedShelfFolder {
        afterEarlierStorageWork { await deleteCart(folder: folder) }
    }
    return .undefined
}

func startShelfActions() {
    _ = document.getElementById("shelf-new").addEventListener("click", newCartClicked)
    _ = document.getElementById("shelf-duplicate").addEventListener("click", duplicateClicked)
    _ = document.getElementById("shelf-delete").addEventListener("click", deleteClicked)
}

private func newCart() -> Cart {
    Cart(
        name: "New cart",
        mainLua: """
            function _init()
            end

            function _update()
            end

            function _draw()
              cls()
            end

            """)
}

private func duplicateCart(folder: String) async {
    guard var copy = await readSavedCart(folder: folder) else {
        return
    }
    let originalName = copy.name
    copy.name = copyName(of: originalName)
    let copyFolder = newFolderName()
    do {
        try await writeCart(copy, folder: copyFolder)
    } catch {
        showStatus("Can't duplicate \(originalName): \(error.thrownValue)")
        try? await refreshShelf()
        return
    }
    selectedShelfFolder = copyFolder
    showStatus("Duplicated \(originalName) as \(copy.name).")
    try? await refreshShelf()
}

private func deleteCart(folder: String) async {
    guard let listed = savedCartsOnShelf.first(where: { $0.folder == folder }) else {
        return
    }
    let title = listed.name ?? "the damaged cart"
    guard await ask(deleteQuestion(for: listed), confirm: "Delete", destructive: true) != nil else {
        return
    }
    let wasOpen = folder == cartFolder
    do {
        try await removeSavedCart(folder: folder)
        if wasOpen {
            openCart(demoCart(), folder: nil)
        }
        showStatus("Deleted \(title).")
    } catch {
        showStatus("Can't delete \(title): \(error.thrownValue)")
    }
    try? await refreshShelf()
    if shownView == .shelf {
        focusShelfSelection()
    }
}

private func deleteQuestion(for listed: (folder: String, name: String?)) -> String {
    let losesUnsavedChanges = listed.folder == cartFolder && cart != lastSavedCart
    switch (listed.name, losesUnsavedChanges) {
    case (let name?, false):
        return "Delete \(name)? This can't be undone. Export it first if you want a backup."
    case (let name?, true):
        return "Delete \(name) and your unsaved changes to it? This can't be undone. Export it first if you want a backup."
    case (nil, false):
        return "Delete the damaged cart? This can't be undone."
    case (nil, true):
        return "Delete the damaged cart and your unsaved changes to \(cart.name)? This can't be undone."
    }
}
