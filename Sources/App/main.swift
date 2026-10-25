import Console
import JavaScriptKit
import Runtime

let document = JSObject.global.document
let canvas = document.getElementById("screen")
canvas.width = .number(Double(Screen.width))
canvas.height = .number(Double(Screen.height))

let context = canvas.getContext("2d")
context.fillStyle = "#3060c0"
_ = context.fillRect(0, 0, Screen.width, Screen.height)

func resultText(of source: String, name: String) -> String {
    do {
        return try runLuaChunk(source, name: name)
    } catch {
        return "error: \(error.message)"
    }
}

let answer = resultText(of: #"return "6 * 7 = " .. 6 * 7"#, name: "answer")
let caught = resultText(of: """
    local ok, message = pcall(function() error("boom") end)
    return "pcall caught: " .. message
    """, name: "fail")
document.getElementById("lua").textContent = .string("\(answer)\n\(caught)")
