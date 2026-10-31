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
}

struct BudgetMeter {
    var instructionsLeft = 0
    var bytesInUse: UInt = 0
    var isMemoryCapped = false
}

// A small step, not the whole budget: each coroutine keeps its own hook counter (decision 012).
private let instructionsPerHookCall: Int32 = 1000

func newStateWithinBudget(meter: UnsafeMutablePointer<BudgetMeter>) -> OpaquePointer {
    lua_newstate(allocateWithinBudget, meter)!
}

func startCountingInstructions(_ state: OpaquePointer) {
    lua_sethook(state, chargeInstructions, LUA_MASKCOUNT, instructionsPerHookCall)
}

private func meter(_ state: OpaquePointer?) -> UnsafeMutablePointer<BudgetMeter> {
    var data: UnsafeMutableRawPointer?
    _ = lua_getallocf(state, &data)
    return data!.assumingMemoryBound(to: BudgetMeter.self)
}

private func chargeInstructions(_ state: OpaquePointer?, _ debug: UnsafeMutablePointer<lua_Debug>?) {
    let meter = meter(state)
    meter.pointee.instructionsLeft -= Int(instructionsPerHookCall)
    guard meter.pointee.instructionsLeft <= 0 else { return }
    lua_sethook(state, chargeInstructions, LUA_MASKCOUNT, 1)
    luaL_where(state, 0)
    lua_pushstring(state, cString("CPU budget exceeded"))
    lua_concat(state, 2)
    _ = lua_error(state)
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
