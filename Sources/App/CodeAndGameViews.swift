import JavaScriptKit
import Runtime

enum ShownView: String {
    case code, game
}

nonisolated(unsafe) var shownView = ShownView.game
nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let codeEditor = JSObject.global.fesCodeEditor

nonisolated(unsafe) private let codeChanged = JSClosure { arguments in
    cart.mainLua = arguments[0].string!
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
}

func runCart() {
    runningCart = RunningCart(mainLua: cart.mainLua, ppu: cart.ppu)
    isErrorShown = false
    document.getElementById("cart-error").textContent = ""
    show(.game)
    _ = document.getElementById("screen").focus()
}

func showCodeView() {
    show(.code)
    _ = codeEditor.focus()
}

private func show(_ view: ShownView) {
    shownView = view
    document.body.dataset.view = .string(view.rawValue)
}
