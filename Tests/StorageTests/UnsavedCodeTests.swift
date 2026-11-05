import Storage
import Testing

@Test(arguments: ["0123456789abcdef", nil])
func aCopyReadsBackTheSame(folder: String?) {
    let copy = UnsavedCode(folder: folder, name: "Mïne 🎮", mainLua: "print(\"a\\b\")\n\tx = 1\r\u{1}\n-- 🎮")
    #expect(UnsavedCode(text: copy.text) == copy)
}

@Test(arguments: [
    "not json",
    "{\"name\": \"Mine\", \"mainLua\": \"x",
    "[\"Mine\", \"x = 1\"]",
    "{\"name\": \"Mine\"}",
    "{\"name\": \"Mine\", \"mainLua\": 1}",
    "{\"mainLua\": \"x = 1\"}",
    "{\"name\": \" \", \"mainLua\": \"x = 1\"}",
    "{\"name\": \"Mine\", \"mainLua\": \"x = 1\", \"folder\": 1}",
])
func textThatIsNotAValidCopyIsRejected(text: String) {
    #expect(UnsavedCode(text: text) == nil)
}

@Test func unknownFieldsAreIgnored() {
    let text = "{\"history\": [1, {\"a\": null}], \"name\": \"Mine\", \"mainLua\": \"x = 1\", \"folder\": \"0123456789abcdef\"}"
    #expect(UnsavedCode(text: text) == UnsavedCode(folder: "0123456789abcdef", name: "Mine", mainLua: "x = 1"))
}
