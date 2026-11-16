import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let renameButton = document.getElementById("code-file-rename")
nonisolated(unsafe) private let deleteButton = document.getElementById("code-file-delete")

nonisolated(unsafe) private let newFileClicked = JSClosure { _ in
    afterEarlierStorageWork { await addCodeFile() }
    return .undefined
}

nonisolated(unsafe) private let renameFileClicked = JSClosure { _ in
    afterEarlierStorageWork { await renameShownCodeFile() }
    return .undefined
}

nonisolated(unsafe) private let deleteFileClicked = JSClosure { _ in
    afterEarlierStorageWork { await deleteShownCodeFile() }
    return .undefined
}

private func addCodeFile() async {
    guard let typed = await ask("New code file name:", confirm: "Add", textField: "") else {
        return
    }
    let name = codeFileName(typed: typed)
    if let problem = cart.addCodeFile(named: name) {
        showStatus("Can't add \(name): \(problem)")
        return
    }
    showStatus("Added \(name).")
    showCodeFilesAfterChange(showing: name)
    _ = codeEditor.focus()
}

private func renameShownCodeFile() async {
    let oldName = shownCodeFile
    guard let typed = await ask("Rename \(oldName) to:", confirm: "Rename", textField: String(oldName.dropLast(".lua".count))) else {
        return
    }
    let newName = codeFileName(typed: typed)
    if newName == oldName {
        return
    }
    if let problem = cart.renameCodeFile(oldName, to: newName) {
        showStatus("Can't rename \(oldName) to \(newName): \(problem)")
        return
    }
    showStatus("Renamed \(oldName) to \(newName).")
    _ = codeEditor.forgetFile(oldName)
    showCodeFilesAfterChange(showing: newName)
}

private func deleteShownCodeFile() async {
    let name = shownCodeFile
    guard await ask("Delete \(name)?", confirm: "Delete", destructive: true) != nil else {
        return
    }
    if let problem = cart.removeCodeFile(named: name) {
        showStatus("Can't delete \(name): \(problem)")
        return
    }
    showStatus("Deleted \(name).")
    _ = codeEditor.forgetFile(name)
    showCodeFilesAfterChange(showing: "main.lua")
    _ = tab(showing: "main.lua").focus()
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

// Decision 039: code file names are lower case whatever was typed.
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
