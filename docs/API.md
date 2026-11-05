# Console API

The functions a cart's Lua code can call. Each call is added by the task that needs it; why they work this way is in `docs/decisions/011-console-api-v0.md`.

## Rules for every call

- Number arguments accept Lua numbers and numeric strings (`"5"`). Anything else is an error: `main.lua:12: bad argument #1 to 'spr' (number expected, got string)`. A missing argument says `got no value`.
- NaN and infinity are errors: `bad argument #2 to 'spr' (finite number expected)`, except in `btn`/`btnp`, which return false.
- Numbers are floored, not truncated: `1.9` is 1 and `-0.5` is -1. Keep fractional positions in your own variables; `x = x + 0.5` moves the sprite every other frame.
- Every number passes through a float, so integers beyond ±2^53 aren't exact: `spr(math.maxinteger, 0, 0)` draws tile 0, not 255.
- Out-of-range values wrap to their field instead of failing:

  | Field | Range |
  |---|---|
  | Sprite position | 16-bit signed, -32768 to 32767 |
  | Tile | 0–255 |
  | Palette | 0–7 |
  | Map cell (column, row) | 0–31 |

- Flip and priority arguments must be `true`, `false` or `nil`. Lua treats `0` as true, so `spr(n, x, y, 0, 1)` is an error instead of a silent flip.
- Optional arguments may be left out or passed as `nil`. Extra arguments are ignored.
- Errors stop the cart like any Lua error, unless you catch them with `pcall`.

## When things show

The calls don't draw. They write the console's hardware state, and the PPU renders the frame after `_draw` returns.

- `spr` takes the next free entry of the 64-entry sprite table, in call order. The first `spr` of a frame is in front. Once 64 are in use, further `spr` calls do nothing until `cls()`.
- Sprites stay in the table from frame to frame until `cls()`. Call `cls()` at the start of `_draw` to redraw every frame, or place sprites once in `_init` and leave them.
- At most 16 sprites show on any one scanline (row of pixels); the later ones in the table are dropped on that row.
- `camera(x, y)` scrolls the map and offsets every *later* `spr`. The map uses the camera in effect when the frame renders; each sprite uses the camera in effect when its `spr` ran.
- So `camera()` in the middle of `_draw` also scrolls the map back to 0, 0. Until the window layer (M4), draw HUD sprites with the camera still set, at `cx + x, cy + y`, where `cx, cy` is the camera position.
- The map repeats every 256 pixels in both directions. Sprites don't wrap.

## Budgets

Each frame's `_update` + `_draw` may run 500,000 Lua instructions (placeholder), and the main chunk + `_init` together get the same. Going over stops the cart with `main.lua:N: CPU budget exceeded`. `pcall` cannot catch it: the next function call, or the next 1,000 instructions, raise it again, and if `_update`, `_draw`, `_init` or the main chunk returns with the budget spent (for example through `return pcall(f)`, or a `coroutine.resume` whose coroutine ran out), the cart stops with `CPU budget exceeded` and no line. A frame that takes longer than 250 ms (placeholder) counts as over budget even if it ran few instructions, so library calls on large data in a loop can't freeze the console. Lua memory is capped at 8 MiB (placeholder). An allocation over the cap is a memory error: `pcall` sees `not enough memory`, and an uncaught one shows `memory budget exceeded` with no line. Recursion that goes too deep shows `stack overflow`.

Two things Lua allows are refused, because Lua turns the instruction count off while they run, so a loop in them could freeze the console. `setmetatable` raises `main.lua:N: __gc metamethods are not allowed` for a metatable with any `__gc` field, so carts have no finalizers; adding `__gc` to a metatable after `setmetatable` does nothing, as in standard Lua. Once the budget is spent, `xpcall` no longer calls its message handler: it returns `false` and the budget error unchanged, and the cart stops at its next function call, within 1,000 instructions, or when its callback returns.

## cls

`cls()`

Empties the sprite table, so the next `spr` uses entry 0. The map is unchanged. Takes no color: the map is always behind the sprites.

```lua
function _draw() cls() spr(0, px, py) end
```

## spr

`spr(n, x, y, [palette=0], [flip_x=false], [flip_y=false], [behind=false])`

Places sprite tile `n` with its top-left corner at `x, y`, minus the camera position.

- `palette`: which of the 8 sprite palettes colors it.
- `flip_x`, `flip_y`: mirror the tile left-right or top-bottom.
- `behind`: draw it behind the map's non-transparent pixels.

Returns nothing.

```lua
spr(0, px, py, 2, facing_left)
```

## btn

`btn(i) -> boolean`

True while button `i` is held. `i` is a number from the button table; anything outside 0–7, including NaN and infinity, returns false. `btn()` with no argument is an error.

```lua
if btn(1) then px = px + 1 end
```

## btnp

`btnp(i) -> boolean`

True only on the first frame button `i` is held. It doesn't repeat while the button stays down.

```lua
if btnp(4) then palette = (palette + 1) % 8 end
```

## mset

`mset(x, y, tile, [palette=0])`

Sets map cell `x, y` (in cells, not pixels: one cell is 8×8 pixels) to background tile `tile` colored with background palette `palette`. Returns nothing.

```lua
mset(0, 0, 1)
```

## mget

`mget(x, y) -> tile, palette`

Returns the tile and palette of map cell `x, y`. Coordinates wrap like the map on screen, so `mget(32, 0)` is `mget(0, 0)`.

```lua
local tile = mget(px // 8, py // 8)
```

## camera

`camera([x=0], [y=0])`

Sets the camera to world position `x, y`: the map scrolls so that pixel is at the top-left of the screen, and every later `spr` subtracts it. `camera()` resets it to 0, 0.

```lua
camera(px - 92, py - 68)
```

## Buttons

| Number | Button | Keyboard | Touch overlay |
|---|---|---|---|
| 0 | Left | ← | D-pad left |
| 1 | Right | → | D-pad right |
| 2 | Up | ↑ | D-pad up |
| 3 | Down | ↓ | D-pad down |
| 4 | A | Z | A, the right face button |
| 5 | B | X | B, the left face button |
| 6 | Start | Enter | Start |
| 7 | Select | Shift | Select |

0–5 are PICO-8's numbers, and A and B are on PICO-8's keys, Z and X. The D-pad's corners press two directions at once.
