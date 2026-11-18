import JavaScriptKit

enum ShownView: String, CaseIterable {
    case code, game, art, shelf, help
}

nonisolated(unsafe) var shownView = ShownView.shelf

func show(_ view: ShownView) {
    let previousView = shownView
    shownView = view
    JSObject.global.document.body.dataset.view = .string(view.rawValue)
    for switchView in ShownView.allCases {
        _ = JSObject.global.document.getElementById("show-\(switchView.rawValue)").setAttribute("aria-pressed", switchView == view ? "true" : "false")
    }
    if view != .art {
        dropArtStroke()
    }
    if previousView == .game && view != .game, let error = runningCart.error {
        showRuntimeErrorInCode(error)
    }
    showPowerLED()
}

func showPowerLED() {
    let state: String
    if shownView == .shelf || !runningCartIsOpenedCart {
        state = "off"
    } else if runningCart.error != nil {
        state = "error"
    } else {
        state = "on"
    }
    JSObject.global.document.body.dataset.led = .string(state)
}
