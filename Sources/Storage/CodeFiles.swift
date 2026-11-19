public struct CodeFile: Equatable {
    public var name: String
    public var text: String
}

private let longestCodeFileStem = 32
let tooManyCodeFiles = "a cart holds at most \(Cart.largestCodeFileCount) code files"

public func codeFileNameProblem(_ name: String) -> String? {
    guard name.hasSuffix(".lua") else {
        return "code file names end in .lua"
    }
    let stem = name.unicodeScalars.dropLast(4)
    if stem.isEmpty {
        return "the name before .lua is empty"
    }
    let allowed: (Unicode.Scalar) -> Bool = { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "_" }
    if !stem.allSatisfy(allowed) {
        return "code file names use a–z, 0–9 and _, such as player.lua"
    }
    if ("0"..."9").contains(stem.first!) {
        return "code file names can't start with a digit"
    }
    if stem.count > longestCodeFileStem {
        return "the name before .lua is longer than \(longestCodeFileStem) characters"
    }
    return nil
}

public func endsInLua(_ name: String) -> Bool {
    name.lowercased().hasSuffix(".lua")
}

extension Cart {
    public static let largestCodeFileCount = 32

    public mutating func addCodeFile(named name: String) -> String? {
        if let problem = codeFileNameProblem(name) {
            return problem
        }
        if codeFiles.contains(where: { $0.name == name }) {
            return "this cart already has it"
        }
        if codeFiles.count >= Cart.largestCodeFileCount {
            return tooManyCodeFiles
        }
        codeFiles.append(CodeFile(name: name, text: ""))
        sortOtherCodeFiles()
        return nil
    }

    public mutating func replaceCodeFiles(with files: [(name: String, text: String)]) -> String? {
        let mainLuas = files.filter { $0.name == "main.lua" }
        guard mainLuas.count == 1 else {
            return "an example needs exactly one main.lua"
        }
        guard files.reduce(0, { $0 + $1.text.utf8.count }) <= Cart.largestArchiveBytes else {
            return "the code is larger than 8 MiB"
        }
        var copy = self
        copy.codeFiles = [CodeFile(name: "main.lua", text: mainLuas[0].text)]
        for file in files where file.name != "main.lua" {
            if let problem = copy.addCodeFile(named: file.name) {
                return "\(file.name): \(problem)"
            }
            copy.replaceText(ofCodeFile: file.name, with: file.text)
        }
        self = copy
        return nil
    }

    public mutating func renameCodeFile(_ name: String, to newName: String) -> String? {
        if name == "main.lua" {
            return "the cart starts from main.lua"
        }
        guard let index = codeFiles.firstIndex(where: { $0.name == name }) else {
            return "this cart has no such file"
        }
        if newName == name {
            return nil
        }
        if let problem = codeFileNameProblem(newName) {
            return problem
        }
        if codeFiles.contains(where: { $0.name == newName }) {
            return "this cart already has it"
        }
        codeFiles[index].name = newName
        sortOtherCodeFiles()
        return nil
    }

    public mutating func replaceText(ofCodeFile name: String, with text: String) {
        if let index = codeFiles.firstIndex(where: { $0.name == name }) {
            codeFiles[index].text = text
        }
    }

    public mutating func removeCodeFile(named name: String) -> String? {
        if name == "main.lua" {
            return "the cart starts from main.lua"
        }
        guard let index = codeFiles.firstIndex(where: { $0.name == name }) else {
            return "this cart has no such file"
        }
        codeFiles.remove(at: index)
        return nil
    }

    private mutating func sortOtherCodeFiles() {
        codeFiles[1...].sort { $0.name < $1.name }
    }
}
