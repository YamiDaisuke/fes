import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let renameButton = document.getElementById("code-file-rename")
nonisolated(unsafe) private let deleteButton = document.getElementById("code-file-delete")

nonisolated(unsafe) private let newFileClicked = JSClosure { _ in
    guard let typed = string(from: JSObject.global.prompt!("New code file name:", "")) else {
        return .undefined
    }
    let name = codeFileName(typed: typed)
    if let problem = cart.addCodeFile(named: name) {
        showStatus("Can't add \(name): \(problem)")
        return .undefined
    }
    showStatus("Added \(name).")
    showCodeFilesAfterChange(showing: name)
    _ = codeEditor.focus()
    return .undefined
}

nonisolated(unsafe) private let renameFileClicked = JSClosure { _ in
    let oldName = shownCodeFile
    guard let typed = string(from: JSObject.global.prompt!("Rename \(oldName) to:", String(oldName.dropLast(4)))) else {
        return .undefined
    }
    let newName = codeFileName(typed: typed)
    if newName == oldName {
        return .undefined
    }
    if let problem = cart.renameCodeFile(oldName, to: newName) {
        showStatus("Can't rename \(oldName) to \(newName): \(problem)")
        return .undefined
    }
    showStatus("Renamed \(oldName) to \(newName).")
    _ = codeEditor.forgetFile(oldName)
    showCodeFilesAfterChange(showing: newName)
    return .undefined
}

nonisolated(unsafe) private let deleteFileClicked = JSClosure { _ in
    let name = shownCodeFile
    guard JSObject.global.confirm!("Delete \(name)?") == .boolean(true) else {
        return .undefined
    }
    if let problem = cart.removeCodeFile(named: name) {
        showStatus("Can't delete \(name): \(problem)")
        return .undefined
    }
    showStatus("Deleted \(name).")
    _ = codeEditor.forgetFile(name)
    showCodeFilesAfterChange(showing: "main.lua")
    _ = tab(showing: "main.lua").focus()
    return .undefined
}

func startCodeFileActions() {
    _ = document.getElementById("code-file-new").addEventListener("click", newFileClicked)
    _ = renameButton.addEventListener("click", renameFileClicked)
    _ = deleteButton.addEventListener("click", deleteFileClicked)
}

func updateRenameAndDeleteButtons() {
    let isMainShown = shownCodeFile == "main.lua"
    renameButton.disabled = .boolean(isMainShown)
    deleteButton.disabled = .boolean(isMainShown)
}

// The iPad keyboard capitalises the first letter typed into a prompt.
private func codeFileName(typed: String) -> String {
    let lowercased = typed.lowercased()
    return lowercased.hasSuffix(".lua") ? lowercased : lowercased + ".lua"
}

private func showCodeFilesAfterChange(showing name: String) {
    shownCodeFile = name
    buildCodeFileTabs()
    _ = codeEditor.openFile(name, cart.codeFiles.first { $0.name == name }!.text)
    keepRecoveryCopy()
    checkSyntaxNow()
}
