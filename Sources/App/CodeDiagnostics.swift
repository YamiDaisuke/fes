import JavaScriptKit
import Runtime

nonisolated(unsafe) private var pendingSyntaxCheck: JSTimer?
nonisolated(unsafe) private var codeError: String?

func checkSyntaxSoon() {
    pendingSyntaxCheck = JSTimer(millisecondsDelay: 500) { showErrorInCode(firstSyntaxError()) }
}

func checkSyntaxNow() {
    pendingSyntaxCheck = nil
    showErrorInCode(firstSyntaxError())
}

private func firstSyntaxError() -> String? {
    let shownFileFirst = cart.codeFiles.filter { $0.name == shownCodeFile } + cart.codeFiles.filter { $0.name != shownCodeFile }
    return shownFileFirst.lazy.compactMap { syntaxError(inLua: $0.text, named: $0.name) }.first
}

func showRuntimeErrorInCode(_ error: String) {
    showErrorInCode(error)
    if let position = codePosition(inError: error, files: cart.codeFiles.map(\.name)) {
        showCodeFile(position.file)
        _ = codeEditor.moveCursorToLine(position.line)
    }
}

func showErrorInCode(_ error: String?) {
    if firstLine(of: error) != firstLine(of: codeError) {
        JSObject.global.document.getElementById("code-error").textContent = .string(firstLine(of: error))
    }
    codeError = error
    markErrorInShownFile()
}

func markErrorInShownFile() {
    if let codeError, let position = codePosition(inError: codeError, files: cart.codeFiles.map(\.name)), position.file == shownCodeFile {
        _ = codeEditor.showError(position.line, firstLine(of: codeError))
    } else {
        _ = codeEditor.clearError()
    }
}

private func firstLine(of error: String?) -> String {
    error?.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
}
