import JavaScriptEventLoop
import JavaScriptKit
import Runtime
import Storage

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let storage = JSObject.global.fesStorage
nonisolated(unsafe) let nameInput = document.getElementById("cart-name")
nonisolated(unsafe) private let saveButton = document.getElementById("cart-save")
nonisolated(unsafe) private let cartStatus = document.getElementById("cart-status")
nonisolated(unsafe) private var lastStorageTask: Task<Void, Never>?

nonisolated(unsafe) private let saveClicked = JSClosure { _ in
    afterEarlierStorageWork { await saveCart() }
    return .undefined
}

func startSavedCarts() {
    showCartName()
    _ = saveButton.addEventListener("click", saveClicked)
    // Read before the first await, so edits made while the carts are listed can't replace the copy before it is offered.
    let recoveryCopyText = readRecoveryCopyText()
    Task { _ = try? await awaitStorage(storage.requestPersistentStorage()) }
    afterEarlierStorageWork {
        var savingIsUnavailable = false
        do {
            try await refreshShelf()
        } catch {
            saveButton.disabled = .boolean(true)
            document.getElementById("shelf-import").disabled = .boolean(true)
            showShelfEntries([])
            savingIsUnavailable = true
        }
        await offerRecoveryCopy(recoveryCopyText)
        if savingIsUnavailable {
            showStatus("Saving is unavailable (Private Browsing?)")
        }
    }
}

func afterEarlierStorageWork(_ work: sending @escaping () async -> Void) {
    let earlier = lastStorageTask
    lastStorageTask = Task {
        await earlier?.value
        await work()
    }
}

private func saveCart() async {
    let name = string(from: nameInput.value) ?? ""
    if let problem = nameProblem(name) {
        showStatus("Can't save: \(problem)")
        return
    }
    var saving = cart
    saving.name = name
    cart.name = name
    let folder = cartFolder ?? newFolderName()
    cartFolder = folder
    if let problem = await removeCodeFiles(notIn: saving, folder: folder) {
        showStatus("Can't save: \(problem)")
        return
    }
    do {
        try await writeCart(saving, folder: folder)
    } catch {
        showStatus("Can't save: \(error.thrownValue)")
        return
    }
    lastSavedCart = saving
    keepRecoveryCopy()
    showStatus("Saved \(name).")
    try? await refreshShelf()
}

private func removeCodeFiles(notIn saving: Cart, folder: String) async -> String? {
    let files: [String]
    do throws(JSException) {
        files = try await names(fromStorage: storage.listCartFiles(folder))
    } catch {
        return "can't look for code files the cart no longer has: \(error.thrownValue)"
    }
    for file in files where endsInLua(file) && !saving.fileNames.contains(file) {
        do throws(JSException) {
            _ = try await awaitStorage(storage.removeCartFile(folder, file))
        } catch {
            return "can't remove \(file), which the cart no longer has: \(error.thrownValue)"
        }
    }
    return nil
}

func writeCart(_ writing: Cart, folder: String) async throws(JSException) {
    var files = writing.files
    let cartJSON = files.removeValue(forKey: "cart.json")!
    for (file, text) in files {
        _ = try await awaitStorage(storage.writeCartFile(folder, file, text))
    }
    _ = try await awaitStorage(storage.writeCartFile(folder, "cart.json", cartJSON))
}

func loadCart(folder: String) async -> Bool {
    if cart != lastSavedCart && JSObject.global.confirm!("Discard unsaved changes to \(cart.name)?") != .boolean(true) {
        return false
    }
    if folder == demoFolder {
        openCart(demoCart(), folder: nil)
        showStatus("Opened the built-in demo.")
        return true
    }
    guard let loaded = await readSavedCart(folder: folder) else {
        return false
    }
    openCart(loaded, folder: folder)
    showStatus("Loaded \(loaded.name).")
    return true
}

func readSavedCart(folder: String) async -> Cart? {
    let listed: [String]
    do {
        listed = try await names(fromStorage: storage.listCartFiles(folder))
    } catch {
        showStatus("Can't read the cart's folder: \(error.thrownValue)")
        return nil
    }
    var files: [String: String] = [:]
    for file in listed where Cart.fixedFileNames.contains(file) || endsInLua(file) {
        do {
            files[file] = string(from: try await awaitStorage(storage.readCartFile(folder, file)))
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

func openCart(_ opened: Cart, folder: String?) {
    dropArtStroke()
    cart = opened
    clearArtHistory()
    lastSavedCart = opened
    cartFolder = folder
    showOpenedCartCode()
    showCartName()
    keepRecoveryCopy()
    redrawArtView()
}

func showCartName() {
    nameInput.value = .string(cart.name)
}

func savedCartName(folder: String) async -> String? {
    guard let value = try? await awaitStorage(storage.readCartFile(folder, "cart.json")), let text = string(from: value) else {
        return nil
    }
    return try? parseCartJSON(withoutByteOrderMark(text)).name
}

private func awaitStorage(_ promise: JSValue) async throws(JSException) -> JSValue {
    try await JSPromise(promise.object!)!.value
}

func names(fromStorage promise: JSValue) async throws(JSException) -> [String] {
    JSArray(try await awaitStorage(promise).object!)!.map { string(from: $0)! }
}

func newFolderName() -> String {
    let digits = String(UInt64.random(in: .min ... .max), radix: 16)
    return String(repeating: "0", count: 16 - digits.count) + digits
}

func showStatus(_ message: String) {
    cartStatus.textContent = .string(message)
}
