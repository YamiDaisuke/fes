import CLua

private let removeUnsafeGlobals = "dofile, loadfile, print, warn, string.dump = nil, nil, nil, nil, nil"
// LUA_REGISTRYINDEX and lua_upvalueindex(1) spelled out: Swift doesn't import those C macros.
private let luaRegistryIndex = -LUAI_MAXSTACK - 1000
private let loadAnyModeUpvalueIndex = luaRegistryIndex - 1

func openSandbox(_ state: OpaquePointer) {
    luaL_requiref(state, "_G", luaopen_base, 1)
    luaL_requiref(state, "string", luaopen_string, 1)
    luaL_requiref(state, "table", luaopen_table, 1)
    luaL_requiref(state, "math", luaopen_math, 1)
    luaL_requiref(state, "utf8", luaopen_utf8, 1)
    luaL_requiref(state, "coroutine", luaopen_coroutine, 1)
    lua_settop(state, 0)
    lua_getglobal(state, "load")
    lua_pushcclosure(state, loadTextOnly, 1)
    lua_setglobal(state, "load")
    guard luaL_loadbufferx(state, removeUnsafeGlobals, removeUnsafeGlobals.utf8.count, "=sandbox", "t") == LUA_OK,
          lua_pcallk(state, 0, 0, 0, 0, nil) == LUA_OK else {
        fatalError("sandbox setup failed: \(String(cString: lua_tolstring(state, -1, nil)!))")
    }
}

private func loadTextOnly(_ state: OpaquePointer?) -> Int32 {
    let loadAnyMode = lua_tocfunction(state, loadAnyModeUpvalueIndex)!
    if lua_gettop(state) < 3 {
        lua_settop(state, 3)
    }
    lua_pushstring(state, "t")
    lua_copy(state, -1, 3)
    lua_settop(state, -2)
    return loadAnyMode(state)
}
