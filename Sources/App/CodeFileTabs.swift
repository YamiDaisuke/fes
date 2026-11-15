import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let codeFileTabs = document.getElementById("code-files")
nonisolated(unsafe) var shownCodeFile = "main.lua"

nonisolated(unsafe) private let tabClicked = JSClosure { arguments in
    if let tab = arguments[0].target.closest("[data-file]").object, let name = string(from: tab.dataset.file) {
        showCodeFile(name)
    }
    return .undefined
}

nonisolated(unsafe) private let tabKeyPressed = JSClosure { arguments in
    let event = arguments[0]
    let names = cart.codeFiles.map(\.name)
    let shown = names.firstIndex(of: shownCodeFile) ?? 0
    let next: Int
    switch string(from: event.key) {
    case "ArrowLeft": next = (shown + names.count - 1) % names.count
    case "ArrowRight": next = (shown + 1) % names.count
    case "Home": next = 0
    case "End": next = names.count - 1
    default: return .undefined
    }
    _ = event.preventDefault()
    showCodeFile(names[next])
    _ = tab(showing: names[next]).focus()
    return .undefined
}

func startCodeFileTabs() {
    _ = codeFileTabs.addEventListener("click", tabClicked)
    _ = codeFileTabs.addEventListener("keydown", tabKeyPressed)
}

func showOpenedCartCode() {
    shownCodeFile = "main.lua"
    _ = codeEditor.forgetFiles()
    buildCodeFileTabs()
    _ = codeEditor.openFile("main.lua", cart.codeFiles[0].text)
    checkSyntaxNow()
}

func showCodeFile(_ name: String) {
    guard let file = cart.codeFiles.first(where: { $0.name == name }) else {
        return
    }
    shownCodeFile = name
    _ = codeEditor.openFile(name, file.text)
    markShownCodeFileTab()
    markErrorInShownFile()
}

func buildCodeFileTabs() {
    codeFileTabs.textContent = ""
    for file in cart.codeFiles {
        let tab = document.createElement("button")
        tab.type = "button"
        _ = tab.setAttribute("role", "tab")
        _ = tab.setAttribute("aria-controls", "code-editor")
        tab.dataset.file = .string(file.name)
        tab.textContent = .string(file.name)
        _ = codeFileTabs.append(tab)
    }
    markShownCodeFileTab()
}

private func markShownCodeFileTab() {
    for file in cart.codeFiles {
        let isShown = file.name == shownCodeFile
        let button = tab(showing: file.name)
        _ = button.setAttribute("aria-selected", isShown ? "true" : "false")
        button.tabIndex = .number(isShown ? 0 : -1)
    }
    _ = tab(showing: shownCodeFile).scrollIntoView(["block": "nearest", "inline": "nearest"])
}

// Code file names are [a-z0-9_]+.lua (codeFileNameProblem), so they need no escaping in a selector.
private func tab(showing name: String) -> JSValue {
    codeFileTabs.querySelector("[data-file=\"\(name)\"]")
}
