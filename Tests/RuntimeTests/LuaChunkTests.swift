import Runtime
import Testing

@Test func returnsTheChunkResultAsText() throws {
    #expect(try runLuaChunk("return 6 * 7", name: "answer") == "42")
}

@Test func uncaughtErrorThrowsWithChunkNameAndLine() {
    let error = #expect(throws: LuaError.self) { try runLuaChunk("\nerror('boom')", name: "fail") }
    #expect(error?.message == "fail:2: boom")
}

@Test func syntaxErrorThrowsWithoutRunning() {
    let error = #expect(throws: LuaError.self) { try runLuaChunk("return 1 +", name: "broken") }
    #expect(error?.message == "broken:1: unexpected symbol near <eof>")
}

@Test func nonStringErrorValueBecomesText() {
    let error = #expect(throws: LuaError.self) { try runLuaChunk("error({})", name: "table") }
    #expect(error?.message.hasPrefix("table: ") == true)
}

@Test func bytecodeIsRejected() {
    let error = #expect(throws: LuaError.self) { try runLuaChunk("\u{1B}Lua", name: "bytecode") }
    #expect(error?.message.contains("attempt to load a binary chunk") == true)
}
