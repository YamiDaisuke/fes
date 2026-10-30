import CLua

public struct LuaError: Error {
    public let message: String
}

public func runLuaChunk(_ source: String, name: String) throws(LuaError) -> String {
    guard let state = luaL_newstate() else { throw LuaError(message: "not enough memory") }
    defer { lua_close(state) }
    luaL_requiref(state, "_G", luaopen_base, 1)
    lua_settop(state, 0)

    guard luaL_loadbufferx(state, source, source.utf8.count, "=\(name)", "t") == LUA_OK,
          lua_pcallk(state, 0, 1, 0, 0, nil) == LUA_OK else {
        throw LuaError(message: topValueAsText(state))
    }
    return topValueAsText(state)
}

private func topValueAsText(_ state: OpaquePointer) -> String {
    var length = 0
    let bytes = luaL_tolstring(state, -1, &length)!
    return String(decoding: UnsafeRawBufferPointer(start: bytes, count: length), as: UTF8.self)
}
