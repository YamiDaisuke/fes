import JavaScriptKit

enum ShownView: String {
    case code, game, art, shelf
}

nonisolated(unsafe) var shownView = ShownView.shelf

func show(_ view: ShownView) {
    let previousView = shownView
    shownView = view
    JSObject.global.document.body.dataset.view = .string(view.rawValue)
    if view != .art {
        dropArtStroke()
    }
    if previousView == .game && view != .game, let error = runningCart.error {
        showRuntimeErrorInCode(error)
    }
}
