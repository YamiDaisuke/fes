import JavaScriptKit
import Storage

nonisolated(unsafe) private let storage = JSObject.global.fesStorage.object!

func keepUnsavedCodeCopy() {
    do {
        if cart == lastSavedCart {
            _ = try storage.throwing.removeUnsavedCode!()
        } else {
            _ = try storage.throwing.writeUnsavedCode!(UnsavedCode(folder: cartFolder, name: cart.name, mainLua: cart.mainLua).text)
        }
    } catch {
        showStatus("Can't keep a copy of unsaved code: \((error as! JSException).thrownValue)")
    }
}

func readUnsavedCodeText() -> String? {
    (try? storage.throwing.readUnsavedCode!())?.string
}

func offerUnsavedCode(_ text: String?) async {
    guard let text else {
        return
    }
    guard let copy = UnsavedCode(text: text),
        JSObject.global.confirm!("Restore unsaved changes to \(copy.name)?") == .boolean(true)
    else {
        keepUnsavedCodeCopy()
        return
    }
    if let folder = copy.folder, let saved = await readSavedCart(folder: folder) {
        openCart(saved, folder: folder)
        showStatus("Restored unsaved changes to \(copy.name).")
    } else {
        cart.name = copy.name
        cartFolder = nil
        showStatus(
            copy.folder == nil
                ? "Restored unsaved changes to \(copy.name)."
                : "Restored unsaved code of \(copy.name) as a new cart: its saved files couldn't be read.")
    }
    cart.mainLua = copy.mainLua
    showCodeInEditor(cart.mainLua)
    showCartName()
    showCodeView()
    keepUnsavedCodeCopy()
}
