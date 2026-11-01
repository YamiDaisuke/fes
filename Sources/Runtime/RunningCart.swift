import CLua
import Console

private let messageHandlerIndex: Int32 = 1
private let globalsIndex: Int32 = 2
private let maxErrorBytes = 8192

public final class RunningCart {
    public private(set) var error: String?
    public internal(set) var ppu: PPU
    var nextSpriteSlot = 0
    private(set) var input = Input()
    private let meter = UnsafeMutablePointer<BudgetMeter>.allocate(capacity: 1)
    private let state: OpaquePointer

    public init(mainLua: String, ppu: PPU = PPU()) {
        self.ppu = ppu
        meter.initialize(to: BudgetMeter())
        state = newStateWithinBudget(meter: meter)
        openSandbox(state)
        registerConsoleAPI(state, cart: self)
        lua_pushcclosure(state, appendTraceback, 0)
        lua_getglobal(state, "_G")

        meter.pointee.startPeriod()
        startCountingInstructions(state)
        meter.pointee.isMemoryCapped = true
        let loadStatus = luaL_loadbufferx(state, mainLua, mainLua.utf8.count, "=main.lua", "t")
        meter.pointee.isMemoryCapped = false
        guard loadStatus == LUA_OK else {
            stop(status: loadStatus)
            return
        }
        callFunctionOnTop()
        callGlobal("_init")
    }

    deinit {
        lua_close(state)
        meter.deallocate()
    }

    public func runFrame(input: Input) {
        self.input = input
        meter.pointee.startPeriod()
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
        meter.pointee.isMemoryCapped = true
        let status = lua_pcallk(state, 0, 0, messageHandlerIndex, 0, nil)
        meter.pointee.isMemoryCapped = false
        if status != LUA_OK {
            stop(status: status)
        } else if meter.pointee.instructionsLeft <= 0 {
            error = "CPU budget exceeded"
        }
    }

    private func stop(status: Int32) {
        var length = 0
        if status == LUA_ERRMEM {
            error = "memory budget exceeded"
        } else if let bytes = lua_tolstring(state, -1, &length) {
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
    let isStringOrNumber = lua_tolstring(state, 1, nil) != nil
    if !isStringOrNumber {
        let tostringGaveString = luaL_callmeta(state, 1, "__tostring") != 0 && lua_type(state, -1) == LUA_TSTRING
        if !tostringGaveString {
            let typeName = String(cString: lua_typename(state, lua_type(state, 1)))
            lua_pushstring(state, "(error object is a \(typeName) value)")
        }
    }
    lua_pushstring(state, "\n")
    luaL_traceback(state, state, nil, 1)
    lua_concat(state, 3)
    return 1
}
