import JavaScriptEventLoop
import JavaScriptKit
import Runtime
import Storage

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let storage = JSObject.global.fesStorage
nonisolated(unsafe) private let nameInput = document.getElementById("cart-name")
nonisolated(unsafe) private let saveButton = document.getElementById("cart-save")
nonisolated(unsafe) private let cartList = document.getElementById("cart-list")
nonisolated(unsafe) private let cartStatus = document.getElementById("cart-status")

nonisolated(unsafe) private let saveClicked = JSClosure { _ in
    Task { await saveCart() }
    return .undefined
}

nonisolated(unsafe) private let cartListClicked = JSClosure { arguments in
    if let folder = arguments[0].target.closest("[data-folder]").object?.dataset.folder.string {
        Task { await loadCart(folder: folder) }
    }
    return .undefined
}

func startSavedCarts() {
    showCartName()
    _ = saveButton.addEventListener("click", saveClicked)
    _ = cartList.addEventListener("click", cartListClicked)
    let unsavedCodeText = readUnsavedCodeText()
    Task {
        _ = try? await awaitStorage(storage.requestPersistentStorage())
        do {
            try await refreshCartList()
        } catch {
            saveButton.disabled = .boolean(true)
            showStatus("Saving is unavailable (Private Browsing?)")
        }
        await offerUnsavedCode(unsavedCodeText)
    }
}

private func saveCart() async {
    let name = nameInput.value.string ?? ""
    if let problem = nameProblem(name) {
        showStatus("Can't save: \(problem)")
        return
    }
    var saving = cart
    saving.name = name
    cart.name = name
    let folder = cartFolder ?? newFolderName()
    cartFolder = folder
    var files = saving.files
    let cartJSON = files.removeValue(forKey: "cart.json")!
    do {
        for (file, text) in files {
            _ = try await awaitStorage(storage.writeCartFile(folder, file, text))
        }
        _ = try await awaitStorage(storage.writeCartFile(folder, "cart.json", cartJSON))
    } catch {
        showStatus("Can't save: \(error.thrownValue)")
        return
    }
    lastSavedCart = saving
    keepUnsavedCodeCopy()
    showStatus("Saved \(name).")
    try? await refreshCartList()
}

private func refreshCartList() async throws(JSException) {
    let folders = JSArray(try await awaitStorage(storage.listCartFolders()).object!)!.map { $0.string! }
    var entries: [(folder: String, name: String)] = []
    for folder in folders {
        entries.append((folder, await savedCartName(folder: folder) ?? "Damaged cart"))
    }
    entries.sort { ($0.name, $0.folder) < ($1.name, $1.folder) }
    cartList.textContent = ""
    for entry in entries {
        let button = document.createElement("button")
        button.type = "button"
        button.dataset.folder = .string(entry.folder)
        button.textContent = .string(entry.name)
        let item = document.createElement("li")
        _ = item.append(button)
        _ = cartList.append(item)
    }
}

private func loadCart(folder: String) async {
    if cart != lastSavedCart && JSObject.global.confirm!("Discard unsaved changes to \(cart.name)?") != .boolean(true) {
        return
    }
    guard let loaded = await readSavedCart(folder: folder) else {
        return
    }
    openCart(loaded, folder: folder)
    showStatus("Loaded \(loaded.name).")
}

func readSavedCart(folder: String) async -> Cart? {
    var files: [String: String] = [:]
    for file in Cart.fileNames {
        do {
            files[file] = try await awaitStorage(storage.readCartFile(folder, file)).string
        } catch {
            showStatus("Can't read \(file): \(error.thrownValue)")
            return nil
        }
    }
    do {
        return try Cart(files: files)
    } catch {
        showStatus("Can't load: \(error)")
        return nil
    }
}

func openCart(_ opened: Cart, folder: String) {
    cart = opened
    lastSavedCart = opened
    cartFolder = folder
    showCodeInEditor(opened.mainLua)
    showCartName()
    keepUnsavedCodeCopy()
}

func showCartName() {
    nameInput.value = .string(cart.name)
}

private func savedCartName(folder: String) async -> String? {
    guard let text = try? await awaitStorage(storage.readCartFile(folder, "cart.json")).string else {
        return nil
    }
    return try? cartName(fromCartJSON: text)
}

private func awaitStorage(_ promise: JSValue) async throws(JSException) -> JSValue {
    try await JSPromise(promise.object!)!.value
}

private func newFolderName() -> String {
    let digits = String(UInt64.random(in: .min ... .max), radix: 16)
    return String(repeating: "0", count: 16 - digits.count) + digits
}

func showStatus(_ message: String) {
    cartStatus.textContent = .string(message)
}
