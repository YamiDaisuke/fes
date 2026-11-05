import CLua
import Console

// Read every argument, then fetch the cart; nothing after the fetch may raise: a Lua error longjmps past Swift releases (docs/decisions/011-console-api-v0.md).
func registerConsoleAPI(_ state: OpaquePointer, cart: RunningCart) {
    let bindings: [(String, lua_CFunction)] = [
        ("cls", cls),
        ("spr", spr),
        ("btn", btn),
        ("btnp", btnp),
        ("mset", mset),
        ("mget", mget),
        ("camera", camera),
    ]
    for (name, function) in bindings {
        lua_pushlightuserdata(state, Unmanaged.passUnretained(cart).toOpaque())
        lua_pushcclosure(state, function, 1)
        lua_setglobal(state, name)
    }
}

private func runningCart(_ state: OpaquePointer?) -> RunningCart {
    Unmanaged<RunningCart>.fromOpaque(lua_touserdata(state, firstUpvalueIndex)!).takeUnretainedValue()
}

private func cls(_ state: OpaquePointer?) -> Int32 {
    let cart = runningCart(state)
    cart.ppu.sprites = SpriteTable()
    cart.nextSpriteSlot = 0
    return 0
}

private func spr(_ state: OpaquePointer?) -> Int32 {
    let tile = checkWrappedInteger(state, 1)
    let x = checkWrappedInteger(state, 2)
    let y = checkWrappedInteger(state, 3)
    let palette = optionalWrappedInteger(state, 4, default: 0)
    let isFlippedHorizontally = optionalBoolean(state, 5)
    let isFlippedVertically = optionalBoolean(state, 6)
    let isBehindBackground = optionalBoolean(state, 7)
    let cart = runningCart(state)
    guard cart.nextSpriteSlot < SpriteTable.count else { return 0 }
    cart.ppu.sprites[cart.nextSpriteSlot] = Sprite(
        x: x - cart.ppu.scrollX,
        y: y - cart.ppu.scrollY,
        tile: tile,
        palette: palette,
        isFlippedHorizontally: isFlippedHorizontally,
        isFlippedVertically: isFlippedVertically,
        isBehindBackground: isBehindBackground
    )
    cart.nextSpriteSlot += 1
    return 0
}

private func btn(_ state: OpaquePointer?) -> Int32 {
    let button = checkButton(state, 1)
    let cart = runningCart(state)
    let isHeld = button.map { cart.input.isHeld($0) } ?? false
    lua_pushboolean(state, isHeld ? 1 : 0)
    return 1
}

private func btnp(_ state: OpaquePointer?) -> Int32 {
    let button = checkButton(state, 1)
    let cart = runningCart(state)
    let wasPressed = button.map { cart.input.wasPressedThisFrame($0) } ?? false
    lua_pushboolean(state, wasPressed ? 1 : 0)
    return 1
}

private func mset(_ state: OpaquePointer?) -> Int32 {
    let column = checkWrappedInteger(state, 1)
    let row = checkWrappedInteger(state, 2)
    let tile = checkWrappedInteger(state, 3)
    let palette = optionalWrappedInteger(state, 4, default: 0)
    let cart = runningCart(state)
    cart.ppu.background[column: column, row: row] = Tilemap.Cell(tile: tile, palette: palette)
    return 0
}

private func mget(_ state: OpaquePointer?) -> Int32 {
    let column = checkWrappedInteger(state, 1)
    let row = checkWrappedInteger(state, 2)
    let cart = runningCart(state)
    let cell = cart.ppu.background[column: column, row: row]
    lua_pushinteger(state, lua_Integer(cell.tile))
    lua_pushinteger(state, lua_Integer(cell.palette))
    return 2
}

private func camera(_ state: OpaquePointer?) -> Int32 {
    let x = optionalWrappedInteger(state, 1, default: 0)
    let y = optionalWrappedInteger(state, 2, default: 0)
    let cart = runningCart(state)
    cart.ppu.scrollX = x
    cart.ppu.scrollY = y
    return 0
}

private func checkFlooredNumber(_ state: OpaquePointer?, _ index: Int32) -> Double {
    let number = luaL_checknumber(state, index)
    guard number.isFinite else {
        // luaL_argerror longjmps to the cart's lua_pcall, so the return below never runs.
        luaL_argerror(state, index, cString("finite number expected"))
        return 0
    }
    return number.rounded(.down)
}

private func checkWrappedInteger(_ state: OpaquePointer?, _ index: Int32) -> Int {
    // 65536 is a multiple of every field width and keeps Int(...) in range on 32-bit wasm: decision 011.
    Int(checkFlooredNumber(state, index).truncatingRemainder(dividingBy: 65536))
}

private func optionalWrappedInteger(_ state: OpaquePointer?, _ index: Int32, default defaultValue: Int) -> Int {
    isAbsent(state, index) ? defaultValue : checkWrappedInteger(state, index)
}

private func optionalBoolean(_ state: OpaquePointer?, _ index: Int32) -> Bool {
    if isAbsent(state, index) { return false }
    luaL_checktype(state, index, LUA_TBOOLEAN)
    return lua_toboolean(state, index) != 0
}

private func checkButton(_ state: OpaquePointer?, _ index: Int32) -> Button? {
    Int(exactly: luaL_checknumber(state, index).rounded(.down)).flatMap { Button(rawValue: $0) }
}

// An implicit String-to-C conversion allocates at -Onone, and the longjmp skips its release.
func cString(_ text: StaticString) -> UnsafePointer<CChar> {
    UnsafeRawPointer(text.utf8Start).assumingMemoryBound(to: CChar.self)
}

private func isAbsent(_ state: OpaquePointer?, _ index: Int32) -> Bool {
    lua_type(state, index) <= LUA_TNIL
}
