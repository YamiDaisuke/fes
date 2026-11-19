import JavaScriptKit
import Storage

nonisolated(unsafe) private let openExampleRequested = JSClosure { arguments in
    guard arguments.count == 2, let name = string(from: arguments[0]), let files = exampleFiles(from: arguments[1]) else {
        return .undefined
    }
    var example = demoCart()
    example.name = name
    if let problem = nameProblem(name) ?? example.replaceCodeFiles(with: files) {
        showStatus("Can't open the example: \(problem)")
        return .undefined
    }
    afterEarlierStorageWork {
        guard await unsavedChangesMayBeDiscarded() else {
            return
        }
        openCart(example, folder: nil)
        showStatus("Opened the example \(name).")
        showCodeView()
    }
    return .undefined
}

private func exampleFiles(from value: JSValue) -> [(name: String, text: String)]? {
    guard let array = value.object.flatMap(JSArray.init) else {
        return nil
    }
    var files: [(name: String, text: String)] = []
    for entry in array {
        guard let name = string(from: entry.file), let text = string(from: entry.text) else {
            return nil
        }
        files.append((name, text))
    }
    return files
}

func startOpenExample() {
    JSObject.global.fesOpenExample = .object(openExampleRequested)
}
