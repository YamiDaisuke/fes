import JavaScriptKit
import Runtime

nonisolated(unsafe) private var pendingSyntaxCheck: JSTimer?
nonisolated(unsafe) private var shownCodeError = ""

func checkSyntaxSoon() {
    pendingSyntaxCheck = JSTimer(millisecondsDelay: 500) { showErrorInCode(syntaxError(inLua: cart.mainLua, named: "main.lua")) }
}

func checkSyntaxNow() {
    pendingSyntaxCheck = nil
    showErrorInCode(syntaxError(inLua: cart.mainLua, named: "main.lua"))
}

func showRuntimeErrorInCode(_ error: String) {
    showErrorInCode(error)
    if let line = mainLuaLine(inError: error) {
        _ = codeEditor.moveCursorToLine(line)
    }
}

func showErrorInCode(_ error: String?) {
    let message = error?.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
    if message != shownCodeError {
        JSObject.global.document.getElementById("code-error").textContent = .string(message)
        shownCodeError = message
    }
    if let error, let line = mainLuaLine(inError: error) {
        _ = codeEditor.showError(line, message)
    } else {
        _ = codeEditor.clearError()
    }
}

private func mainLuaLine(inError error: String) -> Int? {
    guard let position = codePosition(inError: error, files: cart.codeFiles.map(\.name)), position.file == "main.lua" else {
        return nil
    }
    return position.line
}
