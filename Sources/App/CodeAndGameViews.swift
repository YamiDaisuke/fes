import JavaScriptKit
import Runtime

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) let codeEditor = JSObject.global.fesCodeEditor

nonisolated(unsafe) private let codeChanged = JSClosure { arguments in
    cart.replaceText(ofCodeFile: shownCodeFile, with: string(from: arguments[0])!)
    keepRecoveryCopy()
    checkSyntaxSoon()
    return .undefined
}

nonisolated(unsafe) private let runClicked = JSClosure { _ in
    runCart()
    return .undefined
}

nonisolated(unsafe) private let setLabelClicked = JSClosure { _ in
    cart.label = labelOfLastFrame()
    keepRecoveryCopy()
    showStatus("Label set. Save to keep it.")
    return .undefined
}

nonisolated(unsafe) private let codeClicked = JSClosure { _ in
    showCodeView()
    return .undefined
}

func startCodeAndGameViews() {
    startCodeFileTabs()
    startCodeFileActions()
    showOpenedCartCode()
    _ = codeEditor.onCodeChange(codeChanged)
    _ = document.getElementById("run").addEventListener("click", runClicked)
    _ = document.getElementById("set-label").addEventListener("click", setLabelClicked)
    _ = document.getElementById("show-code").addEventListener("click", codeClicked)
}

func runCart() {
    dropArtStroke()
    checkSyntaxNow()
    runningCart = RunningCart(
        mainLua: cart.codeFiles[0].text,
        modules: Dictionary(uniqueKeysWithValues: cart.codeFiles.dropFirst().map { ($0.name, $0.text) }),
        ppu: cart.ppu
    )
    isErrorShown = false
    document.getElementById("cart-error").textContent = ""
    show(.game)
    _ = document.getElementById("screen").focus()
}

func showCodeView() {
    show(.code)
    _ = codeEditor.focus()
}
