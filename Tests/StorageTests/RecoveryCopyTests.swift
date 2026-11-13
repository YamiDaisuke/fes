import Foundation
import Storage
import Testing

private func json(_ object: [String: Any]) -> String {
    String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
}

private func sampleFiles(changing file: String, to value: Any) -> [String: Any] {
    var files: [String: Any] = sampleCart().files
    files[file] = value
    return files
}

@Test(arguments: ["0123456789abcdef", nil])
func aWholeCartCopyReadsBackTheSame(folder: String?) {
    var cart = sampleCart()
    cart.mainLua = "print(\"a\\b\")\n\tx = 1\u{1}\n-- 🎮\n"
    let copy = RecoveryCopy(text: RecoveryCopy.text(folder: folder, cart: cart))
    #expect(copy == RecoveryCopy(folder: folder, edits: .wholeCart(cart)))
}

@Test func aCopyWrittenBeforeWholeCartsReadsAsCodeOnly() {
    let withFolder = RecoveryCopy(text: "{\"name\": \"Mine\", \"mainLua\": \"x = 1\", \"folder\": \"0123456789abcdef\"}")
    #expect(withFolder == RecoveryCopy(folder: "0123456789abcdef", edits: .codeOnly(name: "Mine", mainLua: "x = 1")))
    let withoutFolder = RecoveryCopy(text: "{\"name\": \"Mine\", \"mainLua\": \"x = 1\"}")
    #expect(withoutFolder == RecoveryCopy(folder: nil, edits: .codeOnly(name: "Mine", mainLua: "x = 1")))
}

@Test(arguments: [
    "not json",
    "{}",
    json(["files": "main.lua"]),
    json(["files": sampleCart().files.filter { $0.key != "main.lua" }]),
    json(["files": sampleFiles(changing: "main.lua", to: 1)]),
    json(["files": sampleFiles(changing: "sprites.tiles", to: "0\n")]),
    json(["files": sampleFiles(changing: "cart.json", to: "{\"format\": 3, \"name\": \"Mine\"}")]),
    json(["files": sampleFiles(changing: "cart.json", to: "{\"format\": 2, \"name\": \" \"}")]),
    json(["files": sampleCart().files, "folder": 1]),
    json(["name": "Mine", "mainLua": "x = 1", "folder": 1]),
    json(["name": "Mine", "mainLua": 1]),
    json(["name": " ", "mainLua": "x = 1"]),
])
func copiesThatWouldNotLoadAsACartAreRejected(text: String) {
    #expect(RecoveryCopy(text: text) == nil)
}

@Test func unknownFieldsAndUnknownFilesAreIgnored() {
    let text = json(["history": [1, ["a": NSNull()]], "files": sampleFiles(changing: "notes.txt", to: "hi")])
    #expect(RecoveryCopy(text: text) == RecoveryCopy(folder: nil, edits: .wholeCart(sampleCart())))
}
