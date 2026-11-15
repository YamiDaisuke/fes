import JavaScriptKit
import Runtime

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) let codeEditor = JSObject.global.fesCodeEditor

nonisolated(unsafe) private let codeChanged = JSClosure { arguments in
    cart.mainLua = string(from: arguments[0])!
    keepRecoveryCopy()
    checkSyntaxSoon()
    return .undefined
}

nonisolated(unsafe) private let runClicked = JSClosure { _ in
    runCart()
    return .undefined
}

nonisolated(unsafe) private let codeClicked = JSClosure { _ in
    showCodeView()
    return .undefined
}

func startCodeAndGameViews() {
    showCodeInEditor(cart.mainLua)
    _ = codeEditor.onCodeChange(codeChanged)
    _ = document.getElementById("run").addEventListener("click", runClicked)
    _ = document.getElementById("show-code").addEventListener("click", codeClicked)
}

func showCodeInEditor(_ code: String) {
    _ = codeEditor.setCode(code)
    checkSyntaxNow()
}

func runCart() {
    dropArtStroke()
    checkSyntaxNow()
    let modules = Dictionary(uniqueKeysWithValues: cart.codeFiles.dropFirst().map { ($0.name, $0.text) })
    runningCart = RunningCart(mainLua: cart.mainLua, modules: modules, ppu: cart.ppu)
    isErrorShown = false
    document.getElementById("cart-error").textContent = ""
    show(.game)
    _ = document.getElementById("screen").focus()
}

func showCodeView() {
    show(.code)
    _ = codeEditor.focus()
}
