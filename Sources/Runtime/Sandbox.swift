import CLua

private let removeUnsafeGlobalsAndForceTextLoad = """
    dofile, loadfile, print, warn, string.dump = nil, nil, nil, nil, nil
    local loadAnyMode = load
    function load(chunk, chunkName, _, ...)
      return loadAnyMode(chunk, chunkName, "t", ...)
    end
    """

func openSandbox(_ state: OpaquePointer) {
    luaL_requiref(state, "_G", luaopen_base, 1)
    luaL_requiref(state, "string", luaopen_string, 1)
    luaL_requiref(state, "table", luaopen_table, 1)
    luaL_requiref(state, "math", luaopen_math, 1)
    luaL_requiref(state, "utf8", luaopen_utf8, 1)
    luaL_requiref(state, "coroutine", luaopen_coroutine, 1)
    lua_settop(state, 0)
    let script = removeUnsafeGlobalsAndForceTextLoad
    guard luaL_loadbufferx(state, script, script.utf8.count, "=sandbox", "t") == LUA_OK,
          lua_pcallk(state, 0, 0, 0, 0, nil) == LUA_OK else {
        fatalError("sandbox setup failed: \(String(cString: lua_tolstring(state, -1, nil)!))")
    }
}
