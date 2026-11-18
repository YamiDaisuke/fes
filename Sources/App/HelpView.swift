import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let helpFrame = document.getElementById("help-frame")

nonisolated(unsafe) private let helpClicked = JSClosure { _ in
    show(.help)
    if helpFrame.getAttribute("src").isNull {
        _ = helpFrame.setAttribute("src", "manual/")
    }
    _ = helpFrame.focus()
    return .undefined
}

func startHelpView() {
    _ = document.getElementById("show-help").addEventListener("click", helpClicked)
}
