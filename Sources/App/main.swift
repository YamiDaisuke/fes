import Console
import JavaScriptEventLoop
import JavaScriptKit

JavaScriptEventLoop.installGlobalExecutor()

let canvas = JSObject.global.document.getElementById("screen")
canvas.width = .number(Double(Screen.width))
canvas.height = .number(Double(Screen.height))
// Swift initialises globals outside main.swift on first use, which could be after the first edit.
lastSavedCart = cart
startSavedCarts()
startExportAndImport()
startCodeAndGameViews()
startArtView()
