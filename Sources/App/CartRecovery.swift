import JavaScriptKit
import Storage

nonisolated(unsafe) private let storage = JSObject.global.fesStorage.object!

func keepRecoveryCopy() {
    do {
        if cart == lastSavedCart {
            _ = try storage.throwing.removeRecoveryCopy!()
        } else {
            _ = try storage.throwing.writeRecoveryCopy!(RecoveryCopy.text(folder: cartFolder, cart: cart))
        }
    } catch let error as JSException {
        _ = try? storage.throwing.removeRecoveryCopy!()
        showStatus("Can't keep a recovery copy: \(error.thrownValue)")
    } catch {
        _ = try? storage.throwing.removeRecoveryCopy!()
        showStatus("Can't keep a recovery copy: \(error)")
    }
}

func readRecoveryCopyText() -> String? {
    (try? storage.throwing.readRecoveryCopy!()).flatMap(string(from:))
}

func offerRecoveryCopy(_ text: String?) async {
    guard let text else {
        return
    }
    guard let copy = RecoveryCopy(text: text),
        JSObject.global.confirm!("Restore unsaved changes to \(copy.name)?") == .boolean(true)
    else {
        keepRecoveryCopy()
        return
    }
    if let folder = copy.folder, let saved = await readSavedCart(folder: folder), saved.name == copy.name {
        openCart(saved, folder: folder)
        showStatus("Restored unsaved changes to \(copy.name).")
    } else {
        dropArtStroke()
        cartFolder = nil
        if copy.folder == nil {
            showStatus("Restored unsaved changes to \(copy.name).")
        } else {
            showStatus("Restored unsaved changes to \(copy.name) as a new cart: its saved cart couldn't be read or was renamed.")
        }
    }
    switch copy.edits {
    case .wholeCart(let restored):
        cart = restored
    case .codeOnly(let name, let mainLua):
        cart.name = name
        cart.mainLua = mainLua
    }
    showCodeView()
    showCodeInEditor(cart.mainLua)
    showCartName()
    redrawArtView()
    keepRecoveryCopy()
}
