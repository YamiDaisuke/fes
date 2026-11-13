import Editors
import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let undoButton = document.getElementById("art-undo")
nonisolated(unsafe) private let redoButton = document.getElementById("art-redo")

nonisolated(unsafe) private var artHistory = ArtHistory()

func recordArtEdit(_ edit: String, before: CartArt, merging: Bool = false) {
    artHistory.record(edit, before: before, after: cart.art, merging: merging)
    keepRecoveryCopy()
    redrawUndoButtons()
}

func clearArtHistory() {
    artHistory = ArtHistory()
}

func stopArtHistoryMerging() {
    artHistory.stopMerging()
}

private func undoArtEdit() {
    dropArtStroke()
    guard let step = artHistory.undo(current: cart.art) else {
        showStatus("Nothing to undo.")
        return
    }
    cart.art = step.art
    showStatus("Undid \(step.edit).")
    keepRecoveryCopy()
    redrawArtView()
}

private func redoArtEdit() {
    dropArtStroke()
    guard let step = artHistory.redo(current: cart.art) else {
        showStatus("Nothing to redo.")
        return
    }
    cart.art = step.art
    showStatus("Redid \(step.edit).")
    keepRecoveryCopy()
    redrawArtView()
}

func redrawUndoButtons() {
    _ = undoButton.setAttribute("aria-disabled", artHistory.nextUndo == nil ? "true" : "false")
    _ = undoButton.setAttribute("aria-label", artHistory.nextUndo.map { "Undo \($0)" } ?? "Undo")
    _ = redoButton.setAttribute("aria-disabled", artHistory.nextRedo == nil ? "true" : "false")
    _ = redoButton.setAttribute("aria-label", artHistory.nextRedo.map { "Redo \($0)" } ?? "Redo")
}

nonisolated(unsafe) private let undoClicked = JSClosure { _ in
    undoArtEdit()
    return .undefined
}

nonisolated(unsafe) private let redoClicked = JSClosure { _ in
    redoArtEdit()
    return .undefined
}

nonisolated(unsafe) private let keyPressed = JSClosure { arguments in
    let event = arguments[0]
    guard shownView == .art, event.metaKey.boolean == true, string(from: event.key)?.lowercased() == "z" else {
        return .undefined
    }
    _ = event.preventDefault()
    if event.shiftKey.boolean == true {
        redoArtEdit()
    } else {
        undoArtEdit()
    }
    return .undefined
}

func startArtUndo() {
    _ = undoButton.addEventListener("click", undoClicked)
    _ = redoButton.addEventListener("click", redoClicked)
    _ = document.addEventListener("keydown", keyPressed)
}
