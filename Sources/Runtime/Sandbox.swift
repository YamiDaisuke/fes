import CLua

private let removeUnsafeGlobals = "dofile, loadfile, print, warn, string.dump = nil, nil, nil, nil, nil"
// LUA_REGISTRYINDEX and lua_upvalueindex(1) spelled out: Swift doesn't import those C macros, and sees luaconf.h's LUAI_MAXSTACK, not fes_lua_user.h's (decision 012).
let luaRegistryIndex = -FES_LUA_STACK_SLOTS - 1000
let firstUpvalueIndex = luaRegistryIndex - 1

func openSandbox(_ state: OpaquePointer) {
    luaL_requiref(state, "_G", luaopen_base, 1)
    luaL_requiref(state, "string", luaopen_string, 1)
    luaL_requiref(state, "table", luaopen_table, 1)
    luaL_requiref(state, "math", luaopen_math, 1)
    luaL_requiref(state, "utf8", luaopen_utf8, 1)
    luaL_requiref(state, "coroutine", luaopen_coroutine, 1)
    lua_settop(state, 0)
    wrapGlobal(state, "load", with: loadTextOnly)
    wrapGlobal(state, "setmetatable", with: setmetatableWithoutFinalizers)
    wrapGlobal(state, "xpcall", with: xpcallWithinBudget)
    guard luaL_loadbufferx(state, removeUnsafeGlobals, removeUnsafeGlobals.utf8.count, "=sandbox", "t") == LUA_OK,
          lua_pcallk(state, 0, 0, 0, 0, nil) == LUA_OK else {
        fatalError("sandbox setup failed: \(String(cString: lua_tolstring(state, -1, nil)!))")
    }
}

private func wrapGlobal(_ state: OpaquePointer, _ name: String, with wrapper: lua_CFunction) {
    lua_getglobal(state, name)
    lua_pushcclosure(state, wrapper, 1)
    lua_setglobal(state, name)
}

private func loadTextOnly(_ state: OpaquePointer?) -> Int32 {
    let loadAnyMode = lua_tocfunction(state, firstUpvalueIndex)!
    if lua_gettop(state) < 3 {
        lua_settop(state, 3)
    }
    lua_pushstring(state, "t")
    lua_copy(state, -1, 3)
    lua_settop(state, -2)
    return loadAnyMode(state)
}

// Lua turns hooks off in finalizers, so a __gc could loop unmetered; Lua only marks an object for finalization here (decision 012).
private func setmetatableWithoutFinalizers(_ state: OpaquePointer?) -> Int32 {
    let setmetatable = lua_tocfunction(state, firstUpvalueIndex)!
    if lua_type(state, 2) == LUA_TTABLE {
        lua_pushstring(state, cString("__gc"))
        if lua_rawget(state, 2) != LUA_TNIL {
            luaL_where(state, 1)
            lua_pushstring(state, cString("__gc metamethods are not allowed"))
            lua_concat(state, 2)
            return lua_error(state)
        }
        lua_settop(state, -2)
    }
    return setmetatable(state)
}
