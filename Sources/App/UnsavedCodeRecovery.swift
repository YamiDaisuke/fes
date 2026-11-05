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
    } catch let error as JSException {
        showStatus("Can't keep a copy of unsaved code: \(error.thrownValue)")
    } catch {
        showStatus("Can't keep a copy of unsaved code: \(error)")
    }
}

func readUnsavedCodeText() -> String? {
    (try? storage.throwing.readUnsavedCode!()).flatMap(string(from:))
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
    if let folder = copy.folder, let saved = await readSavedCart(folder: folder), saved.name == copy.name {
        openCart(saved, folder: folder)
        showStatus("Restored unsaved changes to \(copy.name).")
    } else if copy.folder == nil {
        cart.name = copy.name
        cartFolder = nil
        showStatus("Restored unsaved changes to \(copy.name).")
    } else {
        cart.name = copy.name
        cartFolder = nil
        showStatus("Restored unsaved code of \(copy.name) as a new cart: its saved cart couldn't be read or was renamed.")
    }
    cart.mainLua = copy.mainLua
    showCodeView()
    showCodeInEditor(cart.mainLua)
    showCartName()
    keepUnsavedCodeCopy()
}
