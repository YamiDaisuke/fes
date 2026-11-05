import Console
import JavaScriptEventLoop
import JavaScriptKit

JavaScriptEventLoop.installGlobalExecutor()

let canvas = JSObject.global.document.getElementById("screen")
canvas.width = .number(Double(Screen.width))
canvas.height = .number(Double(Screen.height))
startSavedCarts()
