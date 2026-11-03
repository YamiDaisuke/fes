#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private let formatVersion = 1
private let longestName = 64

private struct CartJSON: Codable {
    var format: Int
    var name: String
}

extension Cart {
    public init(files: [String: String]) throws(CartFileError) {
        let json = try parseCartJSON(try fileText("cart.json", in: files))
        self.init(name: json.name, mainLua: try fileText("main.lua", in: files))
        backgroundTiles = try parseTileSheet(try fileText("background.tiles", in: files), file: "background.tiles")
        spriteTiles = try parseTileSheet(try fileText("sprites.tiles", in: files), file: "sprites.tiles")
        (backgroundPalettes, spritePalettes) = try parsePalettes(try fileText("palettes.pal", in: files), file: "palettes.pal")
        background = try parseMap(try fileText("map.map", in: files), file: "map.map")
    }

    public var files: [String: String] {
        [
            "cart.json": cartJSONText(CartJSON(format: formatVersion, name: name)),
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

private func cartJSONText(_ json: CartJSON) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try! encoder.encode(json)
    return String(decoding: data, as: UTF8.self) + "\n"
}

private func parseCartJSON(_ text: String) throws(CartFileError) -> CartJSON {
    let json: CartJSON
    do {
        json = try JSONDecoder().decode(CartJSON.self, from: Data(text.utf8))
    } catch DecodingError.dataCorrupted {
        throw CartFileError(file: "cart.json", reason: "not valid JSON")
    } catch DecodingError.keyNotFound(let key, _) {
        throw CartFileError(file: "cart.json", reason: "missing \"\(key.stringValue)\"")
    } catch {
        throw CartFileError(file: "cart.json", reason: "\"format\" must be an integer and \"name\" a string")
    }
    guard json.format >= 1 else {
        throw CartFileError(file: "cart.json", reason: "format \(json.format) is not valid")
    }
    guard json.format <= formatVersion else {
        throw CartFileError(
            file: "cart.json",
            reason: "This cart was made with a newer FES (format \(json.format)); this FES reads format \(formatVersion).")
    }
    if let problem = nameProblem(json.name) {
        throw CartFileError(file: "cart.json", reason: problem)
    }
    return json
}

func nameProblem(_ name: String) -> String? {
    if name.allSatisfy(\.isWhitespace) {
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
