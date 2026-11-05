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
        for name in entries.keys where !Cart.fileNames.contains(name) {
            if let cartFile = cartFileUnzippedInPlace(ofEntry: name) {
                throw ArchiveError("\(name) could be unzipped as \(cartFile)")
            }
        }
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
    let scalarsFilesRejects: Set<Unicode.Scalar> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
    var scalars = String.UnicodeScalarView(name.unicodeScalars.map { scalarsFilesRejects.contains($0) ? "-" : $0 })
    while scalars.first?.properties.isWhitespace == true {
        scalars.removeFirst()
    }
    if scalars.first == "." {
        scalars.replaceSubrange(scalars.startIndex...scalars.startIndex, with: ["-"])
    }
    var fileName = String(scalars)
    // APFS allows 255 UTF-8 bytes per name; the rest is room for ".fes" and a " (2)" Files or Safari may add.
    while fileName.utf8.count > 200 {
        fileName.removeLast()
    }
    while fileName.last?.isWhitespace == true {
        fileName.removeLast()
    }
    return (fileName.isEmpty ? "cart" : fileName) + ".fes"
}

private func cartFileUnzippedInPlace(ofEntry name: String) -> String? {
    var path = Substring(name.lowercased())
    while path.hasPrefix("/") || path.hasPrefix("./") {
        path = path.dropFirst(path.hasPrefix("/") ? 1 : 2)
    }
    return Cart.fileNames.first { path == $0 || path == $0 + "/" }
}

// String(validating:as:) needs macOS 15, and Package.swift supports macOS 13.
private func strictUTF8Text(_ bytes: [UInt8]) -> String? {
    let text = String(decoding: bytes, as: UTF8.self)
    return Array(text.utf8) == bytes ? text : nil
}
