import CLua

private let messageHandlerIndex: Int32 = 1
private let globalsIndex: Int32 = 2
private let maxErrorBytes = 8192

public final class RunningCart {
    public private(set) var error: String?
    private let state: OpaquePointer

    public init(mainLua: String) {
        state = luaL_newstate()!
        openSandbox(state)
        lua_pushcclosure(state, appendTraceback, 0)
        lua_getglobal(state, "_G")

        guard luaL_loadbufferx(state, mainLua, mainLua.utf8.count, "=main.lua", "t") == LUA_OK else {
            stopWithErrorOnTop()
            return
        }
        callFunctionOnTop()
        callGlobal("_init")
    }

    deinit {
        lua_close(state)
    }

    public func runFrame() {
        callGlobal("_update")
        callGlobal("_draw")
    }

    private func callGlobal(_ name: String) {
        guard error == nil else { return }
        lua_pushstring(state, name)
        lua_rawget(state, globalsIndex)
        if lua_type(state, -1) == LUA_TNIL {
            lua_settop(state, globalsIndex)
            return
        }
        callFunctionOnTop()
    }

    private func callFunctionOnTop() {
        if lua_pcallk(state, 0, 0, messageHandlerIndex, 0, nil) != LUA_OK {
            stopWithErrorOnTop()
        }
    }

    private func stopWithErrorOnTop() {
        var length = 0
        if let bytes = lua_tolstring(state, -1, &length) {
            let shownBytes = UnsafeRawBufferPointer(start: bytes, count: min(length, maxErrorBytes))
            error = String(decoding: shownBytes, as: UTF8.self)
            if length > maxErrorBytes {
                error! += "\n[cut: first \(maxErrorBytes) of \(length) bytes shown]"
            }
        } else {
            error = "(error object is not a string)"
        }
        lua_settop(state, globalsIndex)
    }
}

private func appendTraceback(_ state: OpaquePointer?) -> Int32 {
    if lua_tolstring(state, 1, nil) == nil {
        if luaL_callmeta(state, 1, "__tostring") != 0, lua_type(state, -1) == LUA_TSTRING {
            return 1
        }
        let typeName = String(cString: lua_typename(state, lua_type(state, 1)))
        lua_pushstring(state, "(error object is a \(typeName) value)")
    }
    lua_pushstring(state, "\n")
    luaL_traceback(state, state, nil, 1)
    lua_concat(state, 3)
    return 1
}
