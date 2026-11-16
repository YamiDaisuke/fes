import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let dialog = document.getElementById("ask")
nonisolated(unsafe) private let questionHeading = document.getElementById("ask-question")
nonisolated(unsafe) private let field = document.getElementById("ask-field")
nonisolated(unsafe) private let cancelButton = document.getElementById("ask-cancel")
nonisolated(unsafe) private let confirmButton = document.getElementById("ask-confirm")

nonisolated(unsafe) private var waitingForAnswer: CheckedContinuation<Void, Never>?

nonisolated(unsafe) private let cancelClicked = JSClosure { _ in
    _ = dialog.close()
    return .undefined
}

nonisolated(unsafe) private let dialogClosed = JSClosure { _ in
    waitingForAnswer?.resume()
    waitingForAnswer = nil
    return .undefined
}

// WebKit's showModal lets Tab carry focus out of the dialog to the page body.
nonisolated(unsafe) private let keyPressed = JSClosure { arguments in
    let event = arguments[0]
    guard string(from: event.key) == "Tab" else {
        return .undefined
    }
    let firstKey = field.hidden.boolean == true ? cancelButton : field
    let backwards = event.shiftKey.boolean == true
    let leaving = backwards ? firstKey : confirmButton
    let entering = backwards ? confirmButton : firstKey
    guard string(from: event.target.id) == string(from: leaving.id) else {
        return .undefined
    }
    _ = event.preventDefault()
    _ = entering.focus()
    return .undefined
}

func startAsk() {
    _ = cancelButton.addEventListener("click", cancelClicked)
    _ = dialog.addEventListener("keydown", keyPressed)
    _ = dialog.addEventListener("close", dialogClosed)
}

// Only call from inside afterEarlierStorageWork, so nothing changes the cart while the question is open (decision 048).
func ask(_ question: String, confirm: String, cancel: String = "Cancel", textField: String? = nil, destructive: Bool = false) async -> String? {
    questionHeading.textContent = .string(question)
    confirmButton.textContent = .string(confirm)
    confirmButton.className = .string(destructive ? "key key-stop" : "key key-go")
    cancelButton.textContent = .string(cancel)
    field.hidden = .boolean(textField == nil)
    field.value = .string(textField ?? "")
    dialog.returnValue = .string("")
    await withCheckedContinuation { continuation in
        waitingForAnswer = continuation
        _ = dialog.showModal()
        if textField != nil {
            _ = field.focus()
            _ = field.select()
        } else {
            _ = (destructive ? cancelButton : confirmButton).focus()
        }
    }
    guard string(from: dialog.returnValue) == "confirm" else {
        return nil
    }
    return textField == nil ? "" : string(from: field.value) ?? ""
}
