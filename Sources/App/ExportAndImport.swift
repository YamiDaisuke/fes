import JavaScriptEventLoop
import JavaScriptKit
import Storage

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let files = JSObject.global.fesFiles
nonisolated(unsafe) private let importInput = document.getElementById("cart-import-file")

nonisolated(unsafe) private let exportClicked = JSClosure { _ in
    // Not in a Task: navigator.share must be called while the click's user activation lasts.
    exportCart()
    return .undefined
}

nonisolated(unsafe) private let importClicked = JSClosure { _ in
    _ = importInput.click()
    return .undefined
}

nonisolated(unsafe) private let importFileChosen = JSClosure { _ in
    let file = importInput.files[0]
    guard file.object != nil else {
        return .undefined
    }
    importInput.value = ""
    Task { await importCart(from: file) }
    return .undefined
}

func startExportAndImport() {
    _ = document.getElementById("cart-export").addEventListener("click", exportClicked)
    _ = document.getElementById("cart-import").addEventListener("click", importClicked)
    _ = importInput.addEventListener("change", importFileChosen)
}

private func exportCart() {
    let name = string(from: nameInput.value) ?? ""
    if let problem = nameProblem(name) {
        showStatus("Can't export: \(problem)")
        return
    }
    var exporting = cart
    exporting.name = name
    let archive = exporting.fesArchive
    guard archive.count <= Cart.largestArchiveBytes else {
        showStatus("Can't export: the cart is larger than 8 MiB, so it couldn't be imported")
        return
    }
    let fileName = fesFileName(forCartName: name)
    let saving = JSPromise(files.saveFileToDevice(fileName, JSTypedArray<UInt8>(archive)).object!)!
    Task {
        do throws(JSException) {
            if try await saving.value == .boolean(true) {
                showStatus("Exported \(fileName).")
            }
        } catch {
            showStatus("Can't export: \(error.thrownValue)")
        }
    }
}

private func importCart(from file: JSValue) async {
    let fileName = string(from: file.name) ?? ""
    guard let size = file.size.number, size <= Double(Cart.largestArchiveBytes) else {
        showStatus("Can't import \(fileName): larger than 8 MiB")
        return
    }
    let bytes: [UInt8]
    do {
        let buffer = try await JSPromise(file.arrayBuffer().object!)!.value
        let view = JSTypedArray<UInt8>(unsafelyWrapping: JSObject.global.Uint8Array.function!.new(buffer))
        bytes = view.withUnsafeBytes { Array($0) }
    } catch {
        showStatus("Can't import \(fileName): \(error.thrownValue)")
        return
    }
    let imported: Cart
    do {
        imported = try Cart(fesArchive: bytes)
    } catch {
        showStatus("Can't import \(fileName): \(error)")
        return
    }
    do {
        try await writeCart(imported, folder: newFolderName())
    } catch {
        showStatus("Can't import \(fileName): \(error.thrownValue)")
        return
    }
    showStatus("Imported \(imported.name) as a new cart.")
    try? await refreshCartList()
}
