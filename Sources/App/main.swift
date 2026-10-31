import Console
import JavaScriptKit

let canvas = JSObject.global.document.getElementById("screen")
canvas.width = .number(Double(Screen.width))
canvas.height = .number(Double(Screen.height))
