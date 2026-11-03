private let formatVersion = 1
private let longestName = 64

extension Cart {
    public static let fileNames = ["cart.json", "main.lua", "background.tiles", "sprites.tiles", "palettes.pal", "map.map"]

    public init(files: [String: String]) throws(CartFileError) {
        self.init(name: try cartName(fromCartJSON: fileText("cart.json", in: files)), mainLua: try fileText("main.lua", in: files))
        backgroundTiles = try parseTileSheet(fileText("background.tiles", in: files), file: "background.tiles")
        spriteTiles = try parseTileSheet(fileText("sprites.tiles", in: files), file: "sprites.tiles")
        (backgroundPalettes, spritePalettes) = try parsePalettes(fileText("palettes.pal", in: files), file: "palettes.pal")
        background = try parseMap(fileText("map.map", in: files), file: "map.map")
    }

    public var files: [String: String] {
        [
            "cart.json": cartJSONText(name: name),
            "main.lua": mainLua,
            "background.tiles": tileSheetText(backgroundTiles),
            "sprites.tiles": tileSheetText(spriteTiles),
            "palettes.pal": paletteText(background: backgroundPalettes, sprites: spritePalettes),
            "map.map": mapText(background),
        ]
    }
}

private func fileText(_ file: String, in files: [String: String]) throws(CartFileError) -> String {
    guard let text = files[file] else {
        throw CartFileError(file: file, reason: "file is missing")
    }
    return text
}

private func cartJSONText(name: String) -> String {
    "{\n  \"format\" : \(formatVersion),\n  \"name\" : \(jsonString(name))\n}\n"
}

public func cartName(fromCartJSON text: String) throws(CartFileError) -> String {
    let fields: [String: JSONValue]
    do {
        fields = try parseJSONObject(text)
    } catch {
        throw CartFileError(file: "cart.json", reason: error.reason)
    }
    let wrongTypes = CartFileError(file: "cart.json", reason: "\"format\" must be an integer and \"name\" a string")
    guard let formatValue = fields["format"] else {
        throw CartFileError(file: "cart.json", reason: "missing \"format\"")
    }
    guard case .number(let formatText) = formatValue, let format = Int(formatText) else {
        throw wrongTypes
    }
    guard format >= 1 else {
        throw CartFileError(file: "cart.json", reason: "format \(format) is not valid")
    }
    guard format <= formatVersion else {
        throw CartFileError(
            file: "cart.json",
            reason: "This cart was made with a newer FES (format \(format)); this FES reads format \(formatVersion).")
    }
    guard let nameValue = fields["name"] else {
        throw CartFileError(file: "cart.json", reason: "missing \"name\"")
    }
    guard case .string(let name) = nameValue else {
        throw wrongTypes
    }
    if let problem = nameProblem(name) {
        throw CartFileError(file: "cart.json", reason: problem)
    }
    return name
}

public func nameProblem(_ name: String) -> String? {
    if name.unicodeScalars.allSatisfy({ $0.properties.isWhitespace || $0.properties.generalCategory == .format }) {
        return "the name is empty"
    }
    if name.count > longestName {
        return "the name is longer than \(longestName) characters"
    }
    if name.contains(where: \.isNewline) || name.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) {
        return "the name contains a line break or control character"
    }
    return nil
}
