import CLua

private let mainLuaName = "main.lua"
private let maxErrorBytes = 8192

func loadMainLua(_ state: OpaquePointer, _ mainLua: String, meter: UnsafeMutablePointer<BudgetMeter>) -> Int32 {
    meter.pointee.isMemoryCapped = true
    let status = luaL_loadbufferx(state, mainLua, mainLua.utf8.count, "=" + mainLuaName, "t")
    meter.pointee.isMemoryCapped = false
    return status
}

func errorText(_ state: OpaquePointer, status: Int32) -> String {
    var length = 0
    if status == LUA_ERRMEM {
        return "memory budget exceeded"
    }
    guard let bytes = lua_tolstring(state, -1, &length) else {
        return "(error object is not a string)"
    }
    let shownBytes = UnsafeRawBufferPointer(start: bytes, count: min(length, maxErrorBytes))
    var text = String(decoding: shownBytes, as: UTF8.self)
    if length > maxErrorBytes {
        text += "\n[cut: first \(maxErrorBytes) of \(length) bytes shown]"
    }
    return text
}
