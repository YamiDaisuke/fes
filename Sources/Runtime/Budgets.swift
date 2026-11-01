import CLua
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#endif

public enum Budgets {
    public static let instructionsPerFrame = 500_000
    public static let memoryBytes: UInt = 8 << 20
    public static let wallTimePerPeriod: Duration = .milliseconds(250)
}

struct BudgetMeter {
    var instructionsLeft = 0
    var deadline = ContinuousClock.now
    var hookEventsUntilClockCheck = hookEventsPerClockCheck
    var bytesInUse: UInt = 0
    var isMemoryCapped = false

    mutating func startPeriod() {
        instructionsLeft = Budgets.instructionsPerFrame
        deadline = .now + Budgets.wallTimePerPeriod
    }
}

// A small step, not the whole budget: each coroutine keeps its own hook counter (decision 012).
private let instructionsPerHookCall: Int32 = 1000

// Each clock read goes through the WASI shim's clock_time_get, which builds a BigInt and a DataView, too slow for every call.
private let hookEventsPerClockCheck = 16

func newStateWithinBudget(meter: UnsafeMutablePointer<BudgetMeter>) -> OpaquePointer {
    lua_newstate(allocateWithinBudget, meter)!
}

func startCountingInstructions(_ state: OpaquePointer) {
    lua_sethook(state, enforceCPUBudget, LUA_MASKCOUNT | LUA_MASKCALL, instructionsPerHookCall)
}

private func meter(_ state: OpaquePointer?) -> UnsafeMutablePointer<BudgetMeter> {
    var data: UnsafeMutableRawPointer?
    _ = lua_getallocf(state, &data)
    return data!.assumingMemoryBound(to: BudgetMeter.self)
}

private func enforceCPUBudget(_ state: OpaquePointer?, _ debug: UnsafeMutablePointer<lua_Debug>?) {
    let meter = meter(state)
    let isCountEvent = debug!.pointee.event == LUA_HOOKCOUNT
    if isCountEvent {
        meter.pointee.instructionsLeft -= Int(instructionsPerHookCall)
    }
    meter.pointee.hookEventsUntilClockCheck -= 1
    if meter.pointee.hookEventsUntilClockCheck == 0 {
        meter.pointee.hookEventsUntilClockCheck = hookEventsPerClockCheck
        if ContinuousClock.now >= meter.pointee.deadline {
            meter.pointee.instructionsLeft = 0
        }
    }
    guard meter.pointee.instructionsLeft <= 0 else { return }
    // A call event fires before the callee runs, so level 1 is the line that made the call.
    pushWhereOfNearestLine(state, fromLevel: isCountEvent ? 0 : 1)
    lua_pushstring(state, cString("CPU budget exceeded"))
    lua_concat(state, 2)
    _ = lua_error(state)
}

// Library C code calls C functions too, such as string.rep closing its buffer, so the caller may have no line.
private func pushWhereOfNearestLine(_ state: OpaquePointer?, fromLevel firstLevel: Int32) {
    var level = firstLevel
    var frame = lua_Debug()
    while lua_getstack(state, level, &frame) != 0 {
        lua_getinfo(state, "l", &frame)
        if frame.currentline > 0 { break }
        level += 1
    }
    luaL_where(state, level)
}

private func allocateWithinBudget(
    _ data: UnsafeMutableRawPointer?, _ block: UnsafeMutableRawPointer?, _ oldSize: Int, _ newSize: Int
) -> UnsafeMutableRawPointer? {
    let meter = data!.assumingMemoryBound(to: BudgetMeter.self)
    let oldBytes = block == nil ? 0 : UInt(bitPattern: oldSize)
    let newBytes = UInt(bitPattern: newSize)
    if newBytes == 0 {
        free(block)
        meter.pointee.bytesInUse -= oldBytes
        return nil
    }
    if meter.pointee.isMemoryCapped && newBytes > oldBytes {
        let bytesLeft = Budgets.memoryBytes - min(meter.pointee.bytesInUse, Budgets.memoryBytes)
        if newBytes - oldBytes > bytesLeft { return nil }
    }
    guard let resized = realloc(block, newSize) else { return nil }
    meter.pointee.bytesInUse = meter.pointee.bytesInUse - oldBytes + newBytes
    return resized
}

func xpcallWithinBudget(_ state: OpaquePointer?) -> Int32 {
    let xpcall = lua_tocfunction(state, firstUpvalueIndex)!
    luaL_checktype(state, 2, LUA_TFUNCTION)
    lua_pushvalue(state, 2)
    lua_pushcclosure(state, handleUnlessOutOfInstructions, 1)
    lua_copy(state, -1, 2)
    lua_settop(state, -2)
    return xpcall(state)
}

private func handleUnlessOutOfInstructions(_ state: OpaquePointer?) -> Int32 {
    // Lua turns hooks off inside the hook, so a handler called for the budget error would run unmetered (decision 012).
    guard meter(state).pointee.instructionsLeft > 0 else { return 1 }
    lua_pushvalue(state, firstUpvalueIndex)
    lua_pushvalue(state, 1)
    lua_callk(state, 1, 1, 0, nil)
    return 1
}
