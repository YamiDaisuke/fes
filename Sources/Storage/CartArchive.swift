extension Cart {
    // Lua's memory cap (Runtime/Budgets.swift): a cart whose source is larger couldn't run; see docs/decisions/020-fes-archive.md.
    public static let largestArchiveBytes = 8 << 20

    public var fesArchive: [UInt8] {
        let files = self.files
        return storedZip(Cart.fileNames.map { name in (name: name, bytes: Array(files[name]!.utf8)) })
    }

    public init(fesArchive: [UInt8]) throws {
        guard fesArchive.count <= Cart.largestArchiveBytes else {
            throw ArchiveError("larger than 8 MiB")
        }
        let entries = try readStoredZip(fesArchive)
        var files: [String: String] = [:]
        for name in Cart.fileNames {
            guard let bytes = entries[name] else {
                continue
            }
            guard let text = strictUTF8Text(bytes) else {
                throw CartFileError(file: name, reason: "not valid UTF-8")
            }
            files[name] = text
        }
        try self.init(files: files)
    }
}

public func fesFileName(forCartName name: String) -> String {
    let charactersFilesRejects: Set<Character> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
    var fileName = String(name.map { charactersFilesRejects.contains($0) ? "-" : $0 })
    while fileName.first?.isWhitespace == true {
        fileName.removeFirst()
    }
    while fileName.last?.isWhitespace == true {
        fileName.removeLast()
    }
    if fileName.hasPrefix(".") {
        fileName = "-" + fileName.dropFirst()
    }
    return fileName + ".fes"
}

// String(validating:as:) needs macOS 15, and Package.swift supports macOS 13.
private func strictUTF8Text(_ bytes: [UInt8]) -> String? {
    let text = String(decoding: bytes, as: UTF8.self)
    return Array(text.utf8) == bytes ? text : nil
}
