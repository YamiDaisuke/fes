import Console
import JavaScriptKit

let canvas = JSObject.global.document.getElementById("screen")
canvas.width = .number(Double(Screen.width))
canvas.height = .number(Double(Screen.height))

let context = canvas.getContext("2d")
context.fillStyle = "#3060c0"
_ = context.fillRect(0, 0, Screen.width, Screen.height)
