import JavaScriptKit
import Runtime

nonisolated(unsafe) private var pendingSyntaxCheck: JSTimer?
nonisolated(unsafe) private var shownCodeError = ""

func checkSyntaxSoon() {
    pendingSyntaxCheck = JSTimer(millisecondsDelay: 500) { showErrorInCode(syntaxError(inMainLua: cart.mainLua)) }
}

func checkSyntaxNow() {
    pendingSyntaxCheck = nil
    showErrorInCode(syntaxError(inMainLua: cart.mainLua))
}

func showRuntimeErrorInCode(_ error: String) {
    showErrorInCode(error)
    if let line = mainLuaLine(inError: error) {
        _ = codeEditor.moveCursorToLine(line)
    }
}

func showErrorInCode(_ error: String?) {
    let firstLine = error.map { String($0.prefix(while: { $0 != "\n" })) } ?? ""
    if firstLine != shownCodeError {
        JSObject.global.document.getElementById("code-error").textContent = .string(firstLine)
        shownCodeError = firstLine
    }
    if let error, let line = mainLuaLine(inError: error) {
        _ = codeEditor.showError(line, firstLine)
    } else {
        _ = codeEditor.clearError()
    }
}
