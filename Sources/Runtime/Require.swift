import CLua

func registerRequire(_ state: OpaquePointer, cart: RunningCart) {
    lua_pushlightuserdata(state, Unmanaged.passUnretained(cart).toOpaque())
    lua_createtable(state, 0, 0)
    lua_pushcclosure(state, require, 2)
    lua_setglobal(state, "require")
}

private let loadedModulesIndex = secondUpvalueIndex

// require's own frame holds only plain values: every Swift value lives in loadModule, which can't raise (docs/decisions/037-require.md).
private func require(_ state: OpaquePointer?) -> Int32 {
    luaL_checklstring(state, 1, nil)
    lua_settop(state, 1)
    lua_pushvalue(state, 1)
    let loadedType = lua_rawget(state, loadedModulesIndex)
    if loadedType == LUA_TLIGHTUSERDATA {
        pushPositionAndModuleName(state)
        lua_pushstring(state, cString("' is still loading (circular require)"))
        lua_concat(state, 4)
        return lua_error(state)
    }
    if loadedType != LUA_TNIL {
        return 1
    }
    lua_settop(state, 1)
    switch loadModule(state) {
    case .isMain:
        pushPositionAndModuleName(state)
        lua_pushstring(state, cString("' can't be required: the cart starts from main.lua"))
        lua_concat(state, 4)
        return lua_error(state)
    case .notFound:
        pushPositionAndModuleName(state)
        lua_pushstring(state, cString("' not found: this cart has no file "))
        lua_pushvalue(state, 1)
        lua_pushstring(state, cString(".lua"))
        lua_concat(state, 6)
        return lua_error(state)
    case .failedToLoad:
        return lua_error(state)
    case .loaded:
        break
    }
    lua_pushvalue(state, 1)
    lua_pushlightuserdata(state, nil)
    lua_rawset(state, loadedModulesIndex)
    lua_pushvalue(state, 1)
    lua_callk(state, 1, 1, 0, nil)
    if lua_type(state, -1) == LUA_TNIL {
        lua_settop(state, -2)
        lua_pushboolean(state, 1)
    }
    lua_pushvalue(state, 1)
    lua_pushvalue(state, -2)
    lua_rawset(state, loadedModulesIndex)
    return 1
}

private func pushPositionAndModuleName(_ state: OpaquePointer?) {
    luaL_where(state, 1)
    lua_pushstring(state, cString("module '"))
    lua_pushvalue(state, 1)
}

private enum ModuleLookup {
    case loaded, failedToLoad, isMain, notFound
}

private func loadModule(_ state: OpaquePointer?) -> ModuleLookup {
    var length = 0
    let bytes = lua_tolstring(state, 1, &length)!
    let name = String(decoding: UnsafeRawBufferPointer(start: bytes, count: length), as: UTF8.self)
    if name == "main" {
        return .isMain
    }
    let fileName = name + ".lua"
    guard let source = runningCart(state).modules[fileName] else {
        return .notFound
    }
    let status = luaL_loadbufferx(state, source, source.utf8.count, "=" + fileName, "t")
    return status == LUA_OK ? .loaded : .failedToLoad
}
