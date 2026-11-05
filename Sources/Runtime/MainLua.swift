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
    if status == LUA_ERRMEM {
        return "memory budget exceeded"
    }
    var length = 0
    guard let bytes = lua_tolstring(state, -1, &length) else {
        return "(error object is not a string)"
    }
    var shownLength = min(length, maxErrorBytes)
    let isUTF8ContinuationByte = { (index: Int) in UInt8(bitPattern: bytes[index]) & 0b1100_0000 == 0b1000_0000 }
    while shownLength < length, shownLength > 0, isUTF8ContinuationByte(shownLength) {
        shownLength -= 1
    }
    let shownBytes = UnsafeRawBufferPointer(start: bytes, count: shownLength)
    var text = String(decoding: shownBytes, as: UTF8.self)
    if length > maxErrorBytes {
        text += "\n[cut: first \(maxErrorBytes) of \(length) bytes shown]"
    }
    return text
}

public func syntaxError(inMainLua mainLua: String) -> String? {
    let meter = UnsafeMutablePointer<BudgetMeter>.allocate(capacity: 1)
    meter.initialize(to: BudgetMeter())
    defer { meter.deallocate() }
    let state = newStateWithinBudget(meter: meter)
    defer { lua_close(state) }
    let status = loadMainLua(state, mainLua, meter: meter)
    return status == LUA_OK ? nil : errorText(state, status: status)
}

public func mainLuaLine(inError error: String) -> Int? {
    let prefix = mainLuaName + ":"
    for line in error.split(separator: "\n") {
        let position = line.drop(while: { $0 == "\t" })
        guard position.hasPrefix(prefix) else { continue }
        let digits = position.dropFirst(prefix.count).prefix(while: \.isNumber)
        let afterDigits = position.dropFirst(prefix.count + digits.count)
        if afterDigits.hasPrefix(":"), let number = Int(digits), number > 0 {
            return number
        }
    }
    return nil
}
